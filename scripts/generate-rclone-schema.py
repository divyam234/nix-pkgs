#!/usr/bin/env python3
"""Generate a complete rclone option schema from an rclone binary."""

import argparse
import json
import re
import subprocess
from pathlib import Path


FLAG_RE = re.compile(
    r"^\s*(?:(?:-[A-Za-z0-9],\s*)?)--(?P<name>[a-z0-9][a-z0-9-]*)"
    r"(?:\s+(?P<type>[^\s].*?))?\s{2,}(?P<help>.+)$"
)


def run_json(rclone: str, *args: str):
    result = subprocess.run(
        [rclone, *args],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return json.loads(result.stdout)


def run_text(rclone: str, *args: str) -> str:
    result = subprocess.run(
        [rclone, *args],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return result.stdout



def nix_safe(value):
    """Make JSON values safe for Nix's signed 64-bit integer parser."""
    if isinstance(value, dict):
        return {key: nix_safe(item) for key, item in value.items()}
    if isinstance(value, list):
        return [nix_safe(item) for item in value]
    if isinstance(value, int) and not (-(2**63) <= value <= 2**63 - 1):
        return str(value)
    return value


def normalize_option(option: dict, *, cli_name: str, source: str, group: str | None = None, backend: str | None = None) -> dict:
    out = {
        "name": option.get("Name", cli_name),
        "cliName": cli_name,
        "type": option.get("Type", "string"),
        "help": option.get("Help", ""),
        "required": bool(option.get("Required", False)),
        "sensitive": bool(option.get("Sensitive", False) or option.get("IsPassword", False)),
        "advanced": bool(option.get("Advanced", False)),
        "source": source,
    }
    if group is not None:
        out["group"] = group
    if backend is not None:
        out["backend"] = backend
    if "Default" in option:
        out["default"] = option["Default"]
    if "DefaultStr" in option:
        out["defaultStr"] = option["DefaultStr"]
    if option.get("Examples"):
        out["examples"] = option["Examples"]
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rclone", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    version_text = run_text(args.rclone, "version")
    version_match = re.search(r"^rclone v([^\s]+)", version_text, re.MULTILINE)
    if not version_match:
        raise RuntimeError("could not determine rclone version")

    option_blocks = run_json(args.rclone, "rc", "--loopback", "options/info")
    providers_raw = run_json(args.rclone, "rc", "--loopback", "config/providers")["providers"]
    flags: dict[str, dict] = {}

    # Typed global/feature option blocks.
    for group, options in sorted(option_blocks.items()):
        for option in options:
            name = option["Name"]
            # NoPrefix options are exposed exactly as named. Other option blocks
            # generally use a group prefix on the CLI.
            cli_name = name if option.get("NoPrefix", False) or group == "main" else f"{group}-{name}"
            cli_name = cli_name.replace("_", "-")
            flags[cli_name] = normalize_option(
                option, cli_name=cli_name, source="options/info", group=group
            )

    providers = {}
    for provider in sorted(providers_raw, key=lambda item: item["Name"]):
        name = provider["Name"]
        prefix = provider.get("Prefix") or name
        provider_options = {}
        for option in provider.get("Options") or []:
            option_name = option["Name"]
            cli_name = f"{prefix}-{option_name}".replace("_", "-")
            normalized = normalize_option(
                option,
                cli_name=cli_name,
                source="config/providers",
                backend=name,
            )
            provider_options[option_name] = normalized
            flags[cli_name] = normalized
        providers[name] = {
            "name": name,
            "prefix": prefix,
            "description": provider.get("Description", ""),
            "aliases": provider.get("Aliases") or [],
            "options": provider_options,
        }

    # Cobra's help flags output is the final coverage source. It includes flags
    # which aren't represented by options/info or backend config metadata.
    help_flags = run_text(args.rclone, "help", "flags")
    for line in help_flags.splitlines():
        match = FLAG_RE.match(line)
        if not match:
            continue
        name = match.group("name")
        raw_type = (match.group("type") or "").strip()
        help_text = match.group("help").strip()
        if name in flags:
            flags[name]["help"] = flags[name].get("help") or help_text
            flags[name]["helpType"] = raw_type or None
            continue
        flags[name] = {
            "name": name,
            "cliName": name,
            "type": raw_type or "bool",
            "help": help_text,
            "required": False,
            "sensitive": "password" in name or "secret" in name or "token" in name,
            "advanced": False,
            "source": "help flags",
        }

    schema = {
        "version": version_match.group(1),
        "generator": "scripts/generate-rclone-schema.py",
        "flags": dict(sorted(flags.items())),
        "optionBlocks": option_blocks,
        "providers": providers,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(nix_safe(schema), indent=2, sort_keys=True) + "\n")
    print(
        f"generated {args.output}: {len(schema['flags'])} flags, "
        f"{len(providers)} providers, {len(option_blocks)} option blocks"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
