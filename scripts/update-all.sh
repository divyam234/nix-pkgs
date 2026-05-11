#!/usr/bin/env bash
set -euo pipefail

uv run --with pyyaml python scripts/update-releases.py updates.yml "$@"
nix flake check
nix build .#all
