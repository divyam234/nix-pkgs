#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# ///

"""Prepare IDA Pro release from hexrays.su.

Automates:
  1. Scrape latest release info from hexrays.su
  2. Download via torrent (aria2c)
  3. Extract .run installers for both Linux arches
  4. Include kg_patch (keygen)
  5. Repack into ida-pro-{version}.tar.gz
  6. nix store prefetch-file → get Nix hash
  7. gh release create + upload
  8. Rewrite pkgs/ida-pro/default.nix
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
HEXRAYS_URL = "https://hexrays.su/"
OWN_REPO = "divyam234/nix-pkgs"


def log(msg):
    print(f"  • {msg}", flush=True)


def die(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def run(cmd, cwd=None):
    log(f"$ {' '.join(str(a) for a in cmd)}")
    try:
        subprocess.run(cmd, check=True, cwd=cwd)
    except subprocess.CalledProcessError:
        die(f"command failed: {' '.join(str(a) for a in cmd)}")


def run_output(cmd, cwd=None):
    try:
        return subprocess.run(cmd, check=True, capture_output=True, text=True, cwd=cwd).stdout.strip()
    except subprocess.CalledProcessError as e:
        die(f"command failed: {' '.join(str(a) for a in cmd)}\n{e.stderr}")


# ── scraping ──────────────────────────────────────────────────────

def scrape_latest():
    """Return (version, magnet, torrent_id, sha256_map)."""
    log("Fetching hexrays.su ...")
    req = urllib.request.Request(
        HEXRAYS_URL,
        headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"},
    )
    html = urllib.request.urlopen(req, timeout=30).read().decode()

    m = re.search(r'<details class="rel"(?:\s+open)?>.*?</details>', html, re.DOTALL)
    if not m:
        die("could not find release block on hexrays.su")
    block = m.group(0)

    # version string
    m = re.search(r'<span class="ver">(.*?)</span>', block)
    if not m:
        die("could not find version in release block")
    raw = m.group(1).strip()
    ver = re.sub(r'^IDA(?:\s+Pro)?\s+', '', raw)
    ver = re.sub(r'\s+Beta\s+', '-beta', ver, flags=re.IGNORECASE)
    ver = re.sub(r'\s+SP\s*', 'sp', ver, flags=re.IGNORECASE)
    ver = ver.replace(' ', '')

    # magnet
    m = re.search(r'<a href="(magnet:[^"]+)">', block)
    if not m:
        die("could not find magnet link")
    magnet = m.group(1)

    # torrent id from dn or fallback to dir name from torrent href
    m_tid = re.search(r'[?&]dn=([^&]+)', magnet)
    torrent_id = m_tid.group(1) if m_tid else ""
    if not torrent_id:
        m_tor = re.search(r'href="([^"]+\.torrent)"', block)
        if m_tor:
            torrent_id = Path(m_tor.group(1)).parent.name

    # inline SHA256 hashes from <pre> blocks
    sha256_map = {}
    for pre in re.finditer(r'<pre>(.*?)</pre>', block, re.DOTALL):
        for line in pre.group(1).strip().splitlines():
            parts = line.strip().split(None, 1)
            if len(parts) == 2 and re.match(r'^[0-9a-f]{64}$', parts[0], re.IGNORECASE):
                sha256_map[parts[1]] = parts[0]

    return ver, magnet, torrent_id, sha256_map


# ── torrent download ──────────────────────────────────────────────

def download_torrent(magnet, dest_dir):
    """Download torrent content via aria2c.  Returns the directory with content."""
    log("Downloading via aria2c (this may take a while) ...")
    os.makedirs(dest_dir, exist_ok=True)
    run([
        "aria2c",
        "--seed-time=0",
        "--max-connection-per-server=16",
        "--split=16",
        "--dir", str(dest_dir),
        magnet,
    ])
    items = list(dest_dir.iterdir())
    if len(items) == 1 and items[0].is_dir():
        return items[0]
    return dest_dir


# ── find assets in torrent ────────────────────────────────────────

def find_linux_runs(torrent_dir):
    runs = {}
    # Only look in root of torrent dir or setup/ subdirectory — not misc/ or kg_patch/
    search_dirs = [torrent_dir]
    setup_dir = torrent_dir / "setup"
    if setup_dir.is_dir():
        search_dirs.append(setup_dir)
    for sd in search_dirs:
        for f in sorted(sd.iterdir()):
            if f.name.endswith("linux.run") and "x64linux" in f.name:
                runs["x86_64-linux"] = f
    return runs


def find_kg_patch(torrent_dir):
    for d in torrent_dir.iterdir():
        if d.name == "kg_patch" and d.is_dir():
            return d
    return None


def find_misc(torrent_dir):
    for d in torrent_dir.iterdir():
        if d.name == "misc" and d.is_dir():
            return d
    return None


# ── .run extraction ───────────────────────────────────────────────

def verify_sha256(filepath, expected):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while True:
            chunk = f.read(8192)
            if not chunk:
                break
            h.update(chunk)
    actual = h.hexdigest()
    if actual != expected:
        die(f"SHA256 mismatch for {filepath.name}\n  expected: {expected}\n  actual:   {actual}")
    log(f"SHA256 OK  {filepath.name}")


def _extract_gzip_payload(run_file, dest_dir):
    """Find and extract gzip payload appended to a binary .run file."""
    log(f"Scanning {run_file.name} for embedded gzip payload ...")
    with open(run_file, "rb") as f:
        data = f.read()
    idx = data.find(b"\x1f\x8b\x08")
    if idx < 0:
        die(f"no gzip payload found in {run_file.name}")
    log(f"Found gzip at offset {idx} ({idx/1024:.0f} KB)")
    payload = data[idx:]
    import tarfile, io
    buf = io.BytesIO(payload)
    with tarfile.open(fileobj=buf, mode="r:gz") as tar:
        tar.extractall(path=dest_dir)


def _patch_interpreter(binary):
    """Patch ELF interpreter to work on NixOS if needed."""
    try:
        subprocess.run([str(binary), "--help"], capture_output=True, timeout=5)
        return  # works already
    except (subprocess.CalledProcessError, OSError, subprocess.TimeoutExpired):
        pass

    # Try to find a usable dynamic linker
    candidates = [
        "/lib64/ld-linux-x86-64.so.2",
        "/run/current-system/sw/lib64/ld-linux-x86-64.so.2",
        "/nix/var/nix/profiles/default/lib/ld-linux-x86-64.so.2",
    ]
    try:
        glibc_out = subprocess.run(
            ["nix", "eval", "nixpkgs#glibc.out", "--raw"],
            capture_output=True, text=True, timeout=30,
        ).stdout.strip()
        candidates.insert(0, f"{glibc_out}/lib/ld-linux-x86-64.so.2")
    except Exception:
        pass

    for ld in candidates:
        ld_path = Path(ld)
        if ld_path.exists():
            log(f"Patching interpreter -> {ld}")
            subprocess.run(
                ["patchelf", "--set-interpreter", str(ld_path), str(binary)],
                check=True, capture_output=True,
            )
            return
    die("could not find a usable dynamic linker to patch the binary")


def extract_run(run_file, dest_dir):
    run_file = Path(run_file).resolve()
    dest = Path(dest_dir).resolve()
    os.makedirs(dest, exist_ok=True)
    log(f"Extracting {run_file.name} -> {dest.name}/")

    # Copy to workdir to avoid "Text file busy" if source is held by torrent client
    workdir = dest.parent.parent
    local_copy = workdir / run_file.name
    shutil.copy2(run_file, local_copy)
    local_copy.chmod(0o755)
    run_file = local_copy

    header = run_file.read_bytes()[:4]

    if header[:2] in (b"#!", b"# "):
        # Makeself archive — use sh --noexec (architecture-independent)
        run(["sh", str(run_file), "--noexec", "--target", str(dest)])

    elif header[:4] == b"\x7fELF":
        # Native ELF binary — check if arch matches host
        import platform
        e_machine = int.from_bytes(run_file.read_bytes()[18:20], "little")
        host_arch = platform.machine()
        arch_map = {"x86_64": 62, "aarch64": 183}
        if e_machine == arch_map.get(host_arch):
            _patch_interpreter(run_file)
            run([str(run_file), "--mode", "unattended", "--prefix", str(dest)])
        else:
            _extract_gzip_payload(run_file, dest)

    else:
        _extract_gzip_payload(run_file, dest)

    return dest


# ── tarball ───────────────────────────────────────────────────────

def create_tarball(version, content_dir, output_dir):
    log("Creating tarball ...")
    os.makedirs(output_dir, exist_ok=True)
    tarball = output_dir / f"ida-pro-{version}.tar.gz"
    run(["tar", "czf", str(tarball), "-C", str(content_dir.parent), content_dir.name])
    return tarball


# ── nix hash ──────────────────────────────────────────────────────

def get_nix_hash(tarball_path):
    log("Running nix store prefetch-file ...")
    result = run_output(["nix", "store", "prefetch-file", "--json", str(tarball_path)])
    return json.loads(result)["hash"]


# ── github release ────────────────────────────────────────────────

def upload_github_release(version, tarball_path, repo=OWN_REPO):
    tag = f"ida-pro-{version}"
    log(f"Checking release {tag} ...")
    result = subprocess.run(
        ["gh", "release", "view", tag, "--repo", repo],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        log(f"Release {tag} exists — uploading asset ...")
        run(["gh", "release", "upload", tag, str(tarball_path), "--repo", repo, "--clobber"])
    else:
        log(f"Creating release {tag} ...")
        run([
            "gh", "release", "create", tag,
            str(tarball_path),
            "--repo", repo,
            "--title", f"IDA Pro {version}",
            "--notes", f"IDA Pro {version} release package for Nix",
        ])
    return tag


# ── nix package update ───────────────────────────────────────────

def update_nix_package(version, hash_val):
    pkg_file = REPO_ROOT / "pkgs/ida-pro/default.nix"
    log(f"Updating {pkg_file.relative_to(REPO_ROOT)} ...")
    text = pkg_file.read_text()

    text = re.sub(
        r'^\s*version\s*=\s*"[^"]*"\s*;',
        f'  version = "{version}";',
        text,
        count=1,
        flags=re.MULTILINE,
    )
    text = re.sub(
        r'^\s*hash\s*=\s*"[^"]*"\s*;',
        f'  hash = "{hash_val}";',
        text,
        count=1,
        flags=re.MULTILINE,
    )

    pkg_file.write_text(text)


# ── main ──────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Prepare IDA Pro release from hexrays.su",
    )
    parser.add_argument("--version", help="Override auto-detected version")
    parser.add_argument("--magnet", help="Override magnet link")
    parser.add_argument("--no-upload", action="store_true", help="Skip GitHub release")
    parser.add_argument("--no-nix-update", action="store_true", help="Skip nix package update")
    parser.add_argument("--output-dir", type=Path, default=REPO_ROOT / "_releases",
                        help="Where to write the tarball (default: REPO/_releases)")
    parser.add_argument("--repo", default=OWN_REPO, help="GitHub repo")
    parser.add_argument("--keep", action="store_true", help="Keep temp workdir")
    parser.add_argument("--cache-dir", type=Path,
                        help="Use existing torrent download dir (skip download)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Scrape + print info, then exit (no download)")
    args = parser.parse_args()

    # 1 — scrape
    version, magnet, torrent_id, sha256_map = scrape_latest()
    if args.version:
        version = args.version
    if args.magnet:
        magnet = args.magnet

    if args.dry_run:
        log(f"Version: {version}")
        log(f"Magnet:  {magnet[:70]}...")
        print(f"\n✓ Dry-run complete. Found IDA Pro {version}", flush=True)
        return

    workdir = Path(tempfile.mkdtemp(prefix="ida-prepare-"))

    try:
        # 2 — download (or use cache)
        if args.cache_dir:
            torrent_dir = args.cache_dir.resolve()
            log(f"Using cached torrent dir: {torrent_dir}")
        else:
            torrent_dir = download_torrent(magnet, workdir / "torrent")
            if torrent_id:
                maybe = torrent_dir / torrent_id
                if maybe.is_dir():
                    torrent_dir = maybe

        # 3 — verify & find assets
        runs = find_linux_runs(torrent_dir)
        if not runs:
            die(f"no Linux .run files found in {torrent_dir}")

        for arch, rf in runs.items():
            key = rf.name
            if key in sha256_map:
                verify_sha256(rf, sha256_map[key])
            else:
                log(f"No SHA256 on page for {key} — skipping verify")

        kg_patch = find_kg_patch(torrent_dir)
        misc = find_misc(torrent_dir)

        # 4 — extract
        content_dir = workdir / f"ida-pro-{version}"
        os.makedirs(content_dir)

        for arch, run_file in runs.items():
            extract_run(run_file, content_dir / arch)

        if kg_patch:
            shutil.copytree(kg_patch, content_dir / "kg_patch")
            log(f"Copied kg_patch/")

        if misc and not args.no_upload:
            shutil.copytree(misc, content_dir / "misc")
            log(f"Copied misc/")

        # 5 — tarball
        tarball = create_tarball(version, content_dir, args.output_dir)
        size_mb = tarball.stat().st_size / 1024 / 1024
        log(f"Tarball: {tarball.name}  ({size_mb:.0f} MB)")

        # 6 — nix hash
        hash_val = get_nix_hash(tarball)
        log(f"Nix hash: {hash_val}")

        # 7 — github
        if not args.no_upload:
            upload_github_release(version, tarball, args.repo)

        # 8 — update nix package
        if not args.no_nix_update:
            update_nix_package(version, hash_val)

        print(f"\n✓ Done: IDA Pro {version}  (hash: {hash_val})", flush=True)

    finally:
        if not args.keep:
            shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    main()
