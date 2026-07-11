#!/usr/bin/env bash
set -euo pipefail

uv run --with pyyaml --with semver==3.0.4 python scripts/update-releases.py updates.yml "$@"
nix flake check
nix build .#all
