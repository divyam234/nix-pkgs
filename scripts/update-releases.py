#!/usr/bin/env python3
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

import yaml


def run_gh_release_view(repo):
    result = subprocess.run(
        ["gh", "release", "view", "--repo", repo, "--json", "tagName,name,assets"],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    )
    return json.loads(result.stdout)


def prefetch_hash(url):
    result = subprocess.run(
        ["nix", "store", "prefetch-file", "--json", url],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    )
    return json.loads(result.stdout)["hash"]


def load_manifest(path):
    with path.open() as file:
        data = yaml.safe_load(file)
    if not isinstance(data, dict) or not isinstance(data.get("packages"), dict):
        raise RuntimeError("manifest must contain top-level `packages` mapping")
    return data["packages"]


def current_version(package_text):
    match = re.search(r'^\s*version = "([^"]+)";', package_text, re.MULTILINE)
    if not match:
        raise RuntimeError('could not find `version = "...";` in package file')
    return match.group(1)


def read_top_level_field(package_text, field):
    match = re.search(rf'^\s*{re.escape(field)} = "([^"]+)";', package_text, re.MULTILINE)
    if not match:
        raise RuntimeError(f"could not find `{field} = \"...\";` in package file")
    return match.group(1)


def replace_top_level_field(package_text, field, value):
    pattern = re.compile(rf'(^\s*{re.escape(field)} = ")[^"]+(";)', re.MULTILINE)
    updated_text, count = pattern.subn(rf'\g<1>{value}\2', package_text, count=1)
    if count == 0:
        raise RuntimeError(f"could not find `{field} = \"...\";` in package file")
    return updated_text


def replace_system_field(package_text, system, field, value):
    block_pattern = re.compile(rf'({re.escape(system)} = \{{.*?\n\s*\}};)', re.DOTALL)
    block_match = block_pattern.search(package_text)
    if not block_match:
        raise RuntimeError(f"could not find source block for {system}")

    block = block_match.group(1)
    updated_block, count = re.subn(
        rf'({field} = ")[^"]+(";)',
        rf'\g<1>{value}\2',
        block,
        count=1,
    )
    if count == 0:
        raise RuntimeError(f"could not update {field} for {system}")

    return package_text[: block_match.start(1)] + updated_block + package_text[block_match.end(1) :]


def resolve_asset_name(assets_index, asset_spec):
    if isinstance(asset_spec, str):
        if asset_spec not in assets_index:
            raise RuntimeError(f"release has no asset named {asset_spec}")
        return asset_spec

    if isinstance(asset_spec, dict):
        if "name" in asset_spec:
            name = asset_spec["name"]
            if name not in assets_index:
                raise RuntimeError(f"release has no asset named {name}")
            return name

        pattern = asset_spec.get("pattern")
        if pattern:
            regex = re.compile(pattern)
            matches = sorted(name for name in assets_index if regex.search(name))
            if not matches:
                raise RuntimeError(f"release has no asset matching pattern: {pattern}")
            return matches[-1]

    raise RuntimeError("asset spec must be a string or an object with 'name' or 'pattern'")


def release_version(release, config):
    version_cfg = config.get("version", {})
    source = version_cfg.get("source", "tag")

    if source == "tag":
        return release["tagName"].removeprefix(config.get("tagPrefix", "v"))

    if source == "release-name-date":
        prefix = version_cfg.get("prefix", "")
        match = re.search(r"\d{4}-\d{2}-\d{2}", release.get("name", ""))
        if not match:
            raise RuntimeError("could not find YYYY-MM-DD date in release name")
        return f"{prefix}{match.group(0)}"

    raise RuntimeError(f"unknown version source: {source}")


def update_package(repo_root, package_name, config):
    package_file = repo_root / config["file"]
    package_text = package_file.read_text()
    old_version = current_version(package_text)

    release = run_gh_release_view(config["repo"])
    tag = release["tagName"]
    new_version = release_version(release, config)

    download_tag_field = config.get("downloadTagField")
    if download_tag_field:
        current_download_tag = read_top_level_field(package_text, download_tag_field)
        if tag == current_download_tag:
            print(f"{package_name} is already current: {current_download_tag}")
            return False

    if new_version == old_version:
        print(f"{package_name} is already current: {old_version}")
        return False

    release_assets = {asset["name"]: asset for asset in release.get("assets", [])}
    updates = {}

    for system, asset_spec in config["assets"].items():
        asset_name = resolve_asset_name(release_assets, asset_spec)
        asset_api_url = release_assets[asset_name]["url"]
        updates[system] = {
            "asset": asset_name,
            "hash": prefetch_hash(asset_api_url),
        }

    updated_text = replace_top_level_field(package_text, "version", new_version)

    for system, source in updates.items():
        updated_text = replace_system_field(updated_text, system, "asset", source["asset"])
        updated_text = replace_system_field(updated_text, system, "hash", source["hash"])

    if download_tag_field:
        updated_text = replace_top_level_field(updated_text, download_tag_field, tag)

    package_file.write_text(updated_text)
    print(f"updated {package_name}: {old_version} -> {new_version}")
    for system, source in updates.items():
        print(f"{package_name} {system}: {source['asset']} {source['hash']}")
    return True


def main():
    parser = argparse.ArgumentParser(description="Update package versions/hashes from GitHub releases")
    parser.add_argument("manifest", nargs="?", default="updates.yml", type=Path)
    parser.add_argument("packages", nargs="*", help="Optional package names to update")
    args = parser.parse_args()

    repo_root = Path.cwd()
    package_configs = load_manifest(repo_root / args.manifest)

    selected = args.packages or list(package_configs.keys())
    missing = [name for name in selected if name not in package_configs]
    if missing:
        raise RuntimeError(f"unknown package(s) in manifest: {', '.join(missing)}")

    changed = False
    for package_name in selected:
        changed = update_package(repo_root, package_name, package_configs[package_name]) or changed

    return 0


if __name__ == "__main__":
    sys.exit(main())
