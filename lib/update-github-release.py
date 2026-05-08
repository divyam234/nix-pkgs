#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path


def load_json(path):
    with path.open() as file:
        return json.load(file)


def fetch_json(url):
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "nix-pkgs-updater",
    }
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"

    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        message = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GitHub request failed for {url}: {error.code} {message}") from error


def prefetch_hash(url):
    result = subprocess.run(
        ["nix", "store", "prefetch-file", "--json", url],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    )
    return json.loads(result.stdout)["hash"]


def current_version(package_text):
    match = re.search(r'^\s*version = "([^"]+)";', package_text, re.MULTILINE)
    if not match:
        raise RuntimeError('could not find `version = "...";` in package file')
    return match.group(1)


def release_version(release, config):
    version_source = config.get("versionSource", "tag")
    version_prefix = config.get("versionPrefix", "")

    if version_source == "tag":
        return release["tag_name"].removeprefix(config.get("tagPrefix", "v"))

    if version_source == "release-name-date":
        match = re.search(r"\d{4}-\d{2}-\d{2}", release.get("name", ""))
        if not match:
            raise RuntimeError("could not find YYYY-MM-DD date in release name")
        return f"{version_prefix}{match.group(0)}"

    raise RuntimeError(f"unknown versionSource: {version_source}")


def replace_system_field(package_text, system, field, value):
    block_pattern = re.compile(rf'({re.escape(system)} = \{{.*?\n\s*\}};)', re.DOTALL)
    block_match = block_pattern.search(package_text)
    if not block_match:
        raise RuntimeError(f"could not find source block for {system}")

    block = block_match.group(1)
    updated_block = re.sub(
        rf'({field} = ")[^"]+(";)',
        rf'\g<1>{value}\2',
        block,
        count=1,
    )
    if block == updated_block:
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


def update_package(repo_root, config_path):
    config = load_json(config_path)
    package = config["package"]
    repo = config["repo"]
    package_file = repo_root / config["file"]
    assets = config["assets"]

    package_text = package_file.read_text()
    old_version = current_version(package_text)

    release = fetch_json(f"https://api.github.com/repos/{repo}/releases/latest")
    tag = release["tag_name"]
    new_version = release_version(release, config)

    if new_version == old_version:
        print(f"{package} is already current: {old_version}")
        return False

    release_assets = {asset["name"]: asset for asset in release.get("assets", [])}
    updates = {}

    for system, asset_spec in assets.items():
        asset_name = resolve_asset_name(release_assets, asset_spec)

        url = release_assets[asset_name]["browser_download_url"]
        updates[system] = {
            "asset": asset_name,
            "hash": prefetch_hash(url),
        }

    updated_text = re.sub(
        r'(^\s*version = ")[^"]+(";)',
        rf'\g<1>{new_version}\2',
        package_text,
        count=1,
        flags=re.MULTILINE,
    )

    for system, source in updates.items():
        updated_text = replace_system_field(updated_text, system, "asset", source["asset"])
        updated_text = replace_system_field(updated_text, system, "hash", source["hash"])

    package_file.write_text(updated_text)
    print(f"updated {package}: {old_version} -> {new_version}")
    for system, source in updates.items():
        print(f"{package} {system}: {source['asset']} {source['hash']}")
    return True


def discover_configs(repo_root):
    return sorted((repo_root / "pkgs").glob("*/update.json"))


def main():
    parser = argparse.ArgumentParser(description="Update pinned GitHub release package hashes.")
    parser.add_argument("configs", nargs="*", type=Path, help="Package update.json files")
    parser.add_argument("--all", action="store_true", help="Update every pkgs/*/update.json config")
    args = parser.parse_args()

    repo_root = Path.cwd()
    configs = discover_configs(repo_root) if args.all else args.configs
    if not configs:
        parser.error("pass at least one update.json file or --all")

    changed = False
    for config_path in configs:
        changed = update_package(repo_root, config_path) or changed

    return 0


if __name__ == "__main__":
    sys.exit(main())
