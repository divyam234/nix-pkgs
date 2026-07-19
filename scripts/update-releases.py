#!/usr/bin/env python3
import argparse
import json
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

import semver
import yaml


REPO_ROOT = Path(__file__).resolve().parent.parent
@dataclass
class PackageUpdate:
    name: str
    file: Path
    old_version: str
    new_version: str
    tag: str
    sources: dict
    changed: bool
    text: str


def run_json(command):
    try:
        result = subprocess.run(
            command,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except subprocess.CalledProcessError as error:
        message = error.stderr.strip() or error.stdout.strip() or str(error)
        raise RuntimeError(f"command failed: {' '.join(command)}\n{message}") from error

    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"command returned invalid JSON: {' '.join(command)}") from error


def run_command(command, *, capture=False):
    try:
        return subprocess.run(
            command,
            check=True,
            cwd=REPO_ROOT,
            text=True,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
        )
    except subprocess.CalledProcessError as error:
        message = ""
        if capture:
            message = error.stderr.strip() or error.stdout.strip()
        suffix = f"\n{message}" if message else ""
        raise RuntimeError(f"command failed: {' '.join(command)}{suffix}") from error


def run_gh_releases(repo):
    return run_json(["gh", "api", f"repos/{repo}/releases?per_page=20"])


def run_gh_latest_release(repo):
    return run_json(["gh", "api", f"repos/{repo}/releases/latest"])


def run_gh_selected_releases(config):
    release_cfg = config.get("release", {})
    source = release_cfg.get("source", "latest")

    if source == "latest":
        return [run_gh_latest_release(config["repo"])]
    if source == "list":
        return run_gh_releases(config["repo"])

    raise RuntimeError(f"unknown release source: {source}")


def run_gh_commit(repo, ref):
    return run_json(["gh", "api", f"repos/{repo}/commits/{ref}"])


def prefetch_hash(url):
    return run_json(["nix", "store", "prefetch-file", "--json", url])["hash"]


def prefetch_github_source(repo, rev, *, fetch_submodules=False):
    owner, repo_name = repo.split("/", 1)
    expr = f'''
let
  flake = builtins.getFlake "path:{REPO_ROOT}";
  pkgs = import flake.inputs.nixpkgs {{ system = builtins.currentSystem; }};
in
pkgs.fetchFromGitHub {{
  owner = "{owner}";
  repo = "{repo_name}";
  rev = "{rev}";
  hash = pkgs.lib.fakeHash;
  fetchSubmodules = {str(fetch_submodules).lower()};
}}
'''
    with tempfile.NamedTemporaryFile("w", suffix=".nix") as file:
        file.write(expr)
        file.flush()
        result = subprocess.run(
            ["nix", "build", "--no-link", "--impure", "--file", file.name],
            cwd=REPO_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    output = f"{result.stdout}\n{result.stderr}"
    match = re.search(r"got:\s+(sha256-[A-Za-z0-9+/=]+)", output)
    if not match:
        raise RuntimeError(f"could not prefetch source hash for {repo}@{rev}\n{output.strip()}")
    return match.group(1)


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


def read_system_field(package_text, system, field):
    block_pattern = re.compile(rf'({re.escape(system)} = \{{.*?\n\s*\}};)', re.DOTALL)
    block_match = block_pattern.search(package_text)
    if not block_match:
        raise RuntimeError(f"could not find source block for {system}")
    match = re.search(rf'{re.escape(field)} = "([^"]+)";', block_match.group(1))
    if not match:
        raise RuntimeError(f"could not find {field} for {system}")
    return match.group(1)


def replace_top_level_field(package_text, field, value):
    pattern = re.compile(rf'(^\s*{re.escape(field)} = ")[^"]+(";)', re.MULTILINE)
    updated_text, count = pattern.subn(rf'\g<1>{value}\2', package_text, count=1)
    if count == 0:
        raise RuntimeError(f"could not find `{field} = \"...\";` in package file")
    return updated_text


def github_head_version(current, commit, config):
    version_cfg = config.get("version", {})
    base = version_cfg.get("base") or current.split("-unstable-", 1)[0]
    date = commit["commit"]["committer"]["date"][:10]
    return f"{base}-unstable-{date}"


def replace_system_field(package_text, system, field, value):
    block_pattern = re.compile(rf'({re.escape(system)} = \{{.*?\n\s*\}};)', re.DOTALL)
    block_match = block_pattern.search(package_text)
    if not block_match:
        raise RuntimeError(f"could not find source block for {system}")

    block = block_match.group(1)
    updated_block, count = re.subn(
        rf'({re.escape(field)} = ")[^"]+(";)',
        rf'\g<1>{value}\2',
        block,
        count=1,
    )
    if count == 0:
        raise RuntimeError(f"could not update {field} for {system}")

    return package_text[: block_match.start(1)] + updated_block + package_text[block_match.end(1) :]


def render_version_template(value, version):
    return value.replace("${version}", version)


def resolve_asset_name(assets_index, asset_spec, version):
    if isinstance(asset_spec, str):
        asset_spec = {"name": asset_spec}

    if not isinstance(asset_spec, dict):
        raise RuntimeError("asset spec must be a string or an object with 'name' or 'pattern'")

    if "name" in asset_spec:
        name = asset_spec["name"].format(version=version)
        if name not in assets_index:
            raise RuntimeError(f"release has no asset named {name}")
        return name

    pattern = asset_spec.get("pattern")
    if not pattern:
        raise RuntimeError("asset spec must contain 'name' or 'pattern'")

    regex = re.compile(pattern.format(version=re.escape(version)))
    matches = sorted(name for name in assets_index if regex.search(name))
    if not matches:
        raise RuntimeError(f"release has no asset matching pattern: {pattern}")
    if len(matches) != 1:
        raise RuntimeError(
            f"release has multiple assets matching pattern {pattern}: {', '.join(matches)}"
        )
    return matches[0]


def release_has_configured_assets(release, config):
    asset_specs = config.get("assets")
    if not asset_specs:
        return True

    version = release_version(release, config)
    assets_index = {asset["name"]: asset for asset in release.get("assets", [])}
    for asset_spec in asset_specs.values():
        try:
            resolve_asset_name(assets_index, asset_spec, version)
        except RuntimeError as error:
            if "multiple assets" in str(error):
                raise
            return False
    return True


def release_version(release, config):
    version_cfg = config.get("version", {})
    source = version_cfg.get("source", "tag")

    if source == "tag":
        return release["tag_name"].removeprefix(config.get("tagPrefix", "v"))

    if source == "release-name-date":
        prefix = version_cfg.get("prefix", "")
        match = re.search(r"\d{4}-\d{2}-\d{2}", release.get("name", ""))
        if not match:
            raise RuntimeError("could not find YYYY-MM-DD date in release name")
        return f"{prefix}{match.group(0)}"

    raise RuntimeError(f"unknown version source: {source}")


def parse_semver(version):
    try:
        return semver.Version.parse(version)
    except ValueError:
        return None


def select_release(releases, config):
    release_cfg = config.get("release", {})
    include_drafts = release_cfg.get("includeDrafts", False)
    include_prereleases = release_cfg.get("includePrereleases", False)
    sort_by = release_cfg.get("sortBy", "semver")
    tag_pattern = release_cfg.get("tagPattern")
    tag_regex = re.compile(tag_pattern) if tag_pattern else None

    candidates = []
    for release in releases:
        if release.get("draft") and not include_drafts:
            continue
        if release.get("prerelease") and not include_prereleases:
            continue
        if tag_regex and not tag_regex.fullmatch(release.get("tag_name", "")):
            continue
        if config.get("version", {}).get("requireSemver") and not parse_semver(release_version(release, config)):
            continue
        if not release_has_configured_assets(release, config):
            continue
        candidates.append(release)

    if not candidates:
        raise RuntimeError("no release matched the configured release policy and assets")

    if sort_by == "publishedAt":
        return max(
            candidates,
            key=lambda release: release.get("published_at") or release.get("created_at") or "",
        )
    if sort_by != "semver":
        raise RuntimeError(f"unknown release sort order: {sort_by}")

    versioned = []
    for release in candidates:
        version = release_version(release, config)
        parsed = parse_semver(version)
        if parsed is not None:
            versioned.append((parsed, release))

    if versioned:
        return max(versioned, key=lambda item: item[0])[1]

    return max(candidates, key=lambda release: release.get("published_at") or release.get("created_at") or "")


def prepare_update(repo_root, package_name, config):
    if config.get("source") == "github-head":
        return prepare_github_head_update(repo_root, package_name, config)

    package_file = repo_root / config["file"]
    package_text = package_file.read_text()
    old_version = current_version(package_text)

    release = select_release(run_gh_selected_releases(config), config)
    tag = release["tag_name"]
    new_version = release_version(release, config)

    old_semver = parse_semver(old_version)
    new_semver = parse_semver(new_version)
    if old_semver and new_semver and new_semver < old_semver:
        raise RuntimeError(
            f"refusing to downgrade {package_name} from {old_version} to {new_version}"
        )

    release_assets = {asset["name"]: asset for asset in release.get("assets", [])}
    updates = {}
    used_assets = set()

    for system, asset_spec in config["assets"].items():
        asset_name = resolve_asset_name(release_assets, asset_spec, new_version)
        if asset_name in used_assets and not config.get("allowSharedAsset", False):
            raise RuntimeError(f"asset {asset_name} was selected for more than one platform")
        used_assets.add(asset_name)
        asset_url = release_assets[asset_name].get("browser_download_url") or release_assets[asset_name].get("url")
        if not asset_url:
            raise RuntimeError(f"release asset {asset_name} has no download URL")
        updates[system] = {
            "asset": asset_name,
            "hash": prefetch_hash(asset_url),
        }

    updated_text = replace_top_level_field(package_text, "version", new_version)
    for system, source in updates.items():
        current_asset = read_system_field(package_text, system, "asset")
        if render_version_template(current_asset, new_version) != source["asset"]:
            updated_text = replace_system_field(updated_text, system, "asset", source["asset"])
        updated_text = replace_system_field(updated_text, system, "hash", source["hash"])

    download_tag_field = config.get("downloadTagField")
    if download_tag_field:
        updated_text = replace_top_level_field(updated_text, download_tag_field, tag)

    return PackageUpdate(
        name=package_name,
        file=package_file,
        old_version=old_version,
        new_version=new_version,
        tag=tag,
        sources=updates,
        changed=updated_text != package_text,
        text=updated_text,
    )


def prepare_github_head_update(repo_root, package_name, config):
    package_file = repo_root / config["file"]
    package_text = package_file.read_text()
    old_version = current_version(package_text)
    old_rev = read_top_level_field(package_text, "rev")

    ref = config.get("ref", "HEAD")
    commit = run_gh_commit(config["repo"], ref)
    rev = commit["sha"]
    new_version = github_head_version(old_version, commit, config)
    fetch_submodules = config.get("fetchSubmodules", False)
    source_hash = prefetch_github_source(
        config["repo"],
        rev,
        fetch_submodules=fetch_submodules,
    )

    updated_text = replace_top_level_field(package_text, "version", new_version)
    updated_text = replace_top_level_field(updated_text, "rev", rev)
    updated_text = replace_top_level_field(updated_text, "hash", source_hash)

    return PackageUpdate(
        name=package_name,
        file=package_file,
        old_version=old_version,
        new_version=new_version,
        tag=rev,
        sources={
            "source": {
                "oldRev": old_rev,
                "rev": rev,
                "hash": source_hash,
            }
        },
        changed=updated_text != package_text,
        text=updated_text,
    )


def verify_update(update):
    current_text = update.file.read_text()
    problems = []
    if current_version(current_text) != update.new_version:
        problems.append(f"version is {current_version(current_text)}, expected {update.new_version}")
    if "source" in update.sources:
        source = update.sources["source"]
        current_rev = read_top_level_field(current_text, "rev")
        current_hash = read_top_level_field(current_text, "hash")
        if current_rev != source["rev"]:
            problems.append(f"rev is {current_rev}, expected {source['rev']}")
        if current_hash != source["hash"]:
            problems.append("hash does not match the selected source revision")
        return problems

    for system, source in update.sources.items():
        current_asset = read_system_field(current_text, system, "asset")
        current_hash = read_system_field(current_text, system, "hash")
        if render_version_template(current_asset, update.new_version) != source["asset"]:
            problems.append(f"{system} asset is {current_asset}, expected {source['asset']}")
        if current_hash != source["hash"]:
            problems.append(f"{system} hash does not match the release asset")
    return problems


def run_smoke_test(package_name, config, version):
    test = config.get("test")
    if not test:
        return None

    command = test.get("command") or f"bin/{package_name}"
    args = [str(arg).format(version=version) for arg in test.get("args", ["--version"])]
    executable = REPO_ROOT / "result" / command
    result = run_command([str(executable), *args], capture=True)
    output = f"{result.stdout}\n{result.stderr}".strip()
    expected = test.get("expectedOutput")
    if expected and expected.format(version=version) not in output:
        raise RuntimeError(
            f"smoke test for {package_name} did not contain expected output: "
            f"{expected.format(version=version)!r}"
        )
    return output


def prepare_named_update(repo_root, package_configs, name):
    try:
        return prepare_update(repo_root, name, package_configs[name])
    except RuntimeError as error:
        raise RuntimeError(f"{name}: {error}") from error


def render_report(updates, validation):
    lines = ["# Automated package update", ""]
    changed = [update for update in updates if update.changed]
    if not changed:
        lines.extend(["No package updates were found.", ""])
    for update in changed:
        if "source" in update.sources:
            source = update.sources["source"]
            lines.extend([
                f"## {update.name}: {update.old_version} → {update.new_version}",
                "",
                f"Source revision: `{source['oldRev']}` → `{source['rev']}`",
                "",
                f"Source hash: `{source['hash']}`",
                "",
            ])
            continue

        lines.extend([
            f"## {update.name}: {update.old_version} → {update.new_version}",
            "",
            f"Release tag: `{update.tag}`",
            "",
            "| Platform | Asset | Hash |",
            "| --- | --- | --- |",
        ])
        for system, source in update.sources.items():
            lines.append(f"| `{system}` | `{source['asset']}` | `{source['hash']}` |")
        lines.append("")

    if validation:
        lines.extend(["## Validation", ""])
        lines.extend(f"- {item}" for item in validation)
        lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Update package versions/hashes from GitHub releases")
    parser.add_argument("manifest", nargs="?", default="updates.yml", type=Path)
    parser.add_argument("packages", nargs="*", help="Optional package names to update")
    parser.add_argument("--dry-run", action="store_true", help="Resolve updates without editing files")
    parser.add_argument("--verify", action="store_true", help="Verify current files against selected releases")
    parser.add_argument("--check", action="store_true", help="Run `nix flake check` after updating")
    parser.add_argument("--build", action="store_true", help="Build each changed package")
    parser.add_argument("--smoke-test", action="store_true", help="Run configured smoke tests after builds")
    parser.add_argument("--report", type=Path, help="Write a Markdown update report")
    parser.add_argument("--json", action="store_true", help="Print machine-readable update data")
    parser.add_argument("--jobs", type=int, default=4, help="Package updates to resolve in parallel")
    args = parser.parse_args()

    repo_root = REPO_ROOT
    package_configs = load_manifest(repo_root / args.manifest)
    selected = args.packages or list(package_configs.keys())
    missing = [name for name in selected if name not in package_configs]
    if missing:
        raise RuntimeError(f"unknown package(s) in manifest: {', '.join(missing)}")

    jobs = max(1, min(args.jobs, len(selected)))
    if jobs == 1:
        updates = [prepare_named_update(repo_root, package_configs, name) for name in selected]
    else:
        with ThreadPoolExecutor(max_workers=jobs) as executor:
            updates = list(executor.map(
                lambda name: prepare_named_update(repo_root, package_configs, name),
                selected,
            ))
    validation = []

    if args.verify:
        failures = []
        for update in updates:
            failures.extend(f"{update.name}: {problem}" for problem in verify_update(update))
        if failures:
            raise RuntimeError("verification failed:\n" + "\n".join(failures))
        validation.append("Current versions, assets, and hashes match selected releases")
    elif not args.dry_run:
        for update in updates:
            if update.changed:
                update.file.write_text(update.text)

    changed = [update for update in updates if update.changed]

    if args.check and not args.dry_run:
        run_command(["nix", "flake", "check"])
        validation.append("`nix flake check` passed")

    if args.build and not args.dry_run:
        for update in changed:
            run_command(["nix", "build", f".#{update.name}"])
            validation.append(f"`nix build .#{update.name}` passed")
            if args.smoke_test:
                output = run_smoke_test(update.name, package_configs[update.name], update.new_version)
                if output is not None:
                    validation.append(f"Smoke test for `{update.name}` passed")

    if args.report:
        report_path = repo_root / args.report
        report_path.write_text(render_report(updates, validation))

    if args.json:
        print(json.dumps([
            {
                "name": update.name,
                "oldVersion": update.old_version,
                "newVersion": update.new_version,
                "tag": update.tag,
                "changed": update.changed,
                "sources": update.sources,
            }
            for update in updates
        ], indent=2))
    else:
        for update in updates:
            status = "update available" if update.changed else "current"
            print(f"{update.name}: {update.old_version} -> {update.new_version} ({status})")
            if "source" in update.sources:
                source = update.sources["source"]
                print(f"  source: {source['rev']} {source['hash']}")
                continue
            for system, source in update.sources.items():
                print(f"  {system}: {source['asset']} {source['hash']}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RuntimeError as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(1)
