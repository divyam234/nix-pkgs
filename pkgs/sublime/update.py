#!/usr/bin/env python3
"""Update Sublime in the existing package-update workflow.

Run with ``uv run --with r2pipe python pkgs/sublime/update.py`` and radare2 on PATH.
"""

import json
import re
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PACKAGE = Path(__file__).with_name("default.nix")
PATCHES = Path(__file__).with_name("patches.json")
UPDATE_URL = "https://www.sublimetext.com/updates/4/stable_update_check"


def latest_version():
    with urllib.request.urlopen(UPDATE_URL, timeout=30) as response:
        version = json.load(response)["latest_version"]
    if not isinstance(version, int) or version < 4000:
        raise ValueError(f"unexpected Sublime build number: {version!r}")
    return version


def update():
    text = PACKAGE.read_text()
    match = re.search(r'(?m)^(\s*buildVersion = ")([0-9]+)(";)$', text)
    if match is None:
        raise RuntimeError("could not find buildVersion in Sublime package")
    current = int(match[2])
    latest = latest_version()
    if latest <= current:
        print(f"Sublime is current ({current}); no update needed")
        return

    url = f"https://download.sublimetext.com/sublime_text_build_{latest}_x64.tar.xz"
    # Do not write either file until the generator has finished successfully.
    with tempfile.TemporaryDirectory() as directory:
        candidate = Path(directory) / "patches.json"
        candidate.write_bytes(PATCHES.read_bytes())
        result = subprocess.run(
            [
                sys.executable, str(PACKAGE.with_name("gen_patches.py")), "update",
                "--ref-version", str(current), "--new-version", str(latest),
                "--tarball", url, "--json-path", str(candidate), "--write",
            ],
            cwd=ROOT, text=True, stdout=subprocess.PIPE, check=True,
        )
        if "UNVERIFIED-SIZE" in result.stdout:
            raise RuntimeError("Sublime patch location has an unverified function size; review manually")
        entry = json.loads(candidate.read_text())["versions"][str(latest)]
        if len(entry["patches"]) != len(json.loads(PATCHES.read_text())["versions"][str(current)]["patches"]):
            raise RuntimeError("Sublime patch site count changed; review manually")
        updated = text[:match.start(2)] + str(latest) + text[match.end(2):]
        PATCHES.write_bytes(candidate.read_bytes())
        PACKAGE.write_text(updated)

    # The workflow commits only if building and launching the updated package pass.
    with tempfile.TemporaryDirectory() as directory:
        out_link = Path(directory) / "sublime"
        subprocess.run(["nix", "build", ".#sublime", "--out-link", str(out_link)], cwd=ROOT, check=True)
        subprocess.run([str(out_link / "bin/sublime_text"), "--version"], cwd=ROOT, check=True)
    print(f"Updated Sublime {current} -> {latest}")


if __name__ == "__main__":
    update()
