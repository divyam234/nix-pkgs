# /// script
# requires-python = ">=3.10"
# dependencies = ["r2pipe"]
# ///
"""Retarget Sublime Text license patches from one stable build to the next.

The nix-pkgs ``sublime`` package carries hex patches (xxd) against the
``sublime_text`` binary. Those patches are version-specific: every upstream
release moves the code. This script re-derives them for a new build by
matching masked function bodies from a known-good reference entry in
``patches.json`` (stable 4200 table by default), verifying each hit with
radare2 (function sizes, call-graph shape), and emitting the new JSON entry
plus the xxd lines.

Usage (run from anywhere; uv fetches the ``r2pipe`` dependency)::

    uv run pkgs/sublime/gen_patches.py update \\
        --ref-version 4200 --new-version 4215 \\
        --tarball https://download.sublimetext.com/sublime_text_build_4215_x64.tar.xz \\
        --write

``--write`` inserts the new entry into patches.json (refuses to overwrite
without ``--force``). Without it, the entry is printed for review.

Method (per site kind):

* ``anchor`` (shared validation function): masked 220B body search.
* ``nop-call``: masked pre/post context search around the 5-byte call, then
  verify the call resolves to the anchor entry. Fallback: score every caller
  of the anchor by context similarity and take the best pair.
* ``entry-ret0``: multi-window masked body consensus, then adopt the true
  function start (preceded-by-ret/padding check + radare2 size match).

RIP-relative rel32/disp32 bytes are masked at search time, so only real code
drift can break a match. Every located site is re-verified: pristine bytes
are snapshotted as the new entry's ``original`` field, and the nix build
precondition-checks them before patching.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import struct
import subprocess
import sys
import tarfile
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_JSON = os.path.join(HERE, "patches.json")
CACHE_DIR = os.path.expanduser("~/.cache/sublime-patchgen")

REX_PREFIXES = {0x40, 0x41, 0x44, 0x45, 0x48, 0x49, 0x4C, 0x4D}
MODRM_OPS = {0x8D, 0x8B, 0x89, 0x8F, 0x03, 0x0B, 0x33, 0x3B, 0x2B, 0x23, 0x39, 0x63}
ENTRY_WINDOWS = [(0, 220), (0, 128), (0, 96), (0, 64), (32, 160)]
NOP_WINDOWS = [(-48, 16), (-40, 16), (-32, 12), (-24, 12)]
CHUNK = 32


def log(msg: str) -> None:
    print(msg, flush=True)


# --------------------------------------------------------------------------
# binary helpers
# --------------------------------------------------------------------------

def exec_delta(data: bytes) -> int:
    """File-offset -> vaddr delta for the executable PT_LOAD segment."""
    e_phoff = struct.unpack_from("<Q", data, 0x20)[0]
    e_phentsize, e_phnum = struct.unpack_from("<HH", data, 0x36)
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type, p_flags, p_offset, p_vaddr = struct.unpack_from("<IIQQ", data, off)
        if p_type == 1 and (p_flags & 1) and (p_flags & 4):  # PT_LOAD, X+R
            return p_vaddr - p_offset
    raise ValueError("no executable PT_LOAD segment found")


def mask_bytes(data: bytes) -> list:
    """Mask RIP-relative rel32/disp32 fields; returns bytes/None list."""
    out: list = []
    i, n = 0, len(data)
    while i < n:
        b = data[i]
        if b in (0xE8, 0xE9) and i + 4 < n:
            out += [b, None, None, None, None]
            i += 5
            continue
        if b == 0x0F and i + 1 < n and 0x80 <= data[i + 1] <= 0x8F and i + 5 < n:
            out += [b, data[i + 1], None, None, None, None]
            i += 6
            continue
        j = i
        if data[j] in REX_PREFIXES and j + 1 < n:
            j += 1
        op = data[j]
        if op in MODRM_OPS and j + 1 < n and (data[j + 1] & 0xC7) == 0x05 and j + 5 < n:
            out += list(data[i : j + 2]) + [None] * 4
            i = j + 6
            continue
        if op == 0xFF and j + 1 < n and (data[j + 1] & 0xC7) == 0x05 and j + 5 < n:
            out += list(data[i : j + 2]) + [None] * 4
            i = j + 6
            continue
        if op == 0xC7 and j + 1 < n and (data[j + 1] & 0xC7) == 0x05 and j + 9 < n:
            out += list(data[i : j + 2]) + [None] * 4 + list(data[j + 6 : j + 10])
            i = j + 10
            continue
        out.append(b)
        i += 1
    return out


def compile_masked(masked: list) -> "re.Pattern[bytes]":
    parts = [b"." if x is None else re.escape(bytes([x])) for x in masked]
    return re.compile(b"".join(parts), re.DOTALL)


def find_all(blob: bytes, masked: list, cap: int = 8) -> list[int]:
    rx = compile_masked(masked)
    hits = []
    for m in rx.finditer(blob):
        hits.append(m.start())
        if len(hits) >= cap:
            break
    return hits


def fixed_count(masked: list) -> int:
    return sum(1 for x in masked if x is not None)


def callers_of(blob: bytes, target: int) -> list[int]:
    hits = []
    for i in range(len(blob) - 5):
        if blob[i] == 0xE8 and struct.unpack_from("<i", blob, i + 1)[0] + i + 5 == target:
            hits.append(i)
    return hits


# --------------------------------------------------------------------------
# radare2 backend (r2pipe primary, r2 CLI fallback)
# --------------------------------------------------------------------------

class R2:
    def __init__(self, path: str):
        self.path = path
        self.mode = "unavailable"
        self._r = None
        try:
            import r2pipe  # noqa: PLC0415  (loaded via uv)

            self._r = r2pipe.open(path, flags=["-a", "x86", "-b", "64"])
            self._r.cmd("e scr.color=0")
            self.mode = "r2pipe"
        except Exception as exc:  # noqa: BLE001
            log(f"[r2] r2pipe unavailable ({exc}); falling back to r2 CLI")
            if self._r is not None:
                try:
                    self._r.quit()
                except Exception:  # noqa: BLE001, S110
                    pass
                self._r = None
            self.mode = "cli" if self._cli_ok() else "unavailable"
        log(f"[r2] backend: {self.mode}")

    def _cli_ok(self) -> bool:
        try:
            p = subprocess.run(["r2", "-v"], capture_output=True, text=True, timeout=30)
            return p.returncode == 0 and "radare2" in (p.stdout + p.stderr).lower()
        except Exception:  # noqa: BLE001
            return False

    def func_size(self, vaddr: int) -> int | None:
        """Create a function at vaddr (entry point) and return its size."""
        try:
            if self.mode == "r2pipe":
                self._r.cmd(f"s 0x{vaddr:x}; af")
                info = json.loads(self._r.cmd("afij"))
                return int(info[0]["size"]) if info else None
            if self.mode == "cli":
                p = subprocess.run(
                    ["r2", "-q", "-a", "x86", "-b", "64", "-e", "scr.color=0",
                     "-c", f"s 0x{vaddr:x}; af; afij", self.path],
                    capture_output=True, text=True, timeout=300,
                )
                info = json.loads(p.stdout.strip().splitlines()[-1])
                return int(info[0]["size"]) if info else None
        except Exception as exc:  # noqa: BLE001
            log(f"[r2] func_size failed @0x{vaddr:x}: {exc}")
        return None

    def close(self) -> None:
        if self._r is not None:
            try:
                self._r.quit()
            except Exception:  # noqa: BLE001, S110
                pass


# --------------------------------------------------------------------------
# locating
# --------------------------------------------------------------------------

def locate_anchor(blob: bytes, body_hex: str) -> tuple[int | None, str]:
    body = bytes.fromhex(body_hex)
    for start, length in [(0, 220), (0, 128), (0, 96)]:
        masked = mask_bytes(body[start : start + length])
        if fixed_count(masked) < 40:
            continue
        hits = find_all(blob, masked, cap=4)
        if len(hits) == 1:
            return hits[0], f"window[{start}:{start + length}] unique"
    return None, "no unique window hit"


def prev_is_boundary(blob: bytes, e: int) -> str | None:
    """Why position e looks like a function start (None if not)."""
    if e <= 0 or e >= len(blob):
        return None
    if blob[e - 1] in (0xC3, 0xCB, 0xC2, 0xCA, 0xCC, 0x90):
        return f"prev=0x{blob[e - 1]:02x}"
    if e >= 2 and blob[e - 2] == 0xEB:
        return "prev=jmp-rel8"
    if e >= 5 and blob[e - 5] == 0xE9:
        return "prev=jmp-rel32"
    return None


def prefix_best(blob: bytes, at: int, ref_body: bytes, length: int = 32) -> float:
    """Best masked fixed-byte match of ref_body[:length] at `at` (shifts 0/4/8).

    Tolerates a grown prologue: the reference prefix may align a few bytes
    after the true entry.
    """
    ref = ref_body[:length]
    best = 0.0
    for shift in (0, 4, 8):
        seg = blob[at + shift:at + shift + length]
        if len(seg) < length:
            continue
        masked = mask_bytes(ref)
        fixed = total = 0
        for i, m in enumerate(masked):
            if m is None:
                continue
            total += 1
            if seg[i] == m:
                fixed += 1
        if total:
            best = max(best, fixed / total)
    return best


def chunk_runs(blob: bytes, body: bytes) -> list[tuple[int, int, int]]:
    """Qualifying linear runs: (start_chunk_off, base, length), earliest first.

    A run is consecutive 32B chunks whose (hit - off) base stays clustered.
    The earliest run anchors closest to the function entry, so callers try
    runs in start order.
    """
    matches: list[tuple[int, int]] = []  # (chunk_off, hit)
    for off in range(0, len(body) - CHUNK, CHUNK):
        masked = mask_bytes(body[off:off + CHUNK])
        if fixed_count(masked) < 20:
            continue
        for h in find_all(blob, masked, cap=4):
            matches.append((off, h))
    runs: list[tuple[int, int, int]] = []
    for i in range(len(matches)):
        run = [matches[i]]
        for j in range(i + 1, len(matches)):
            if matches[j][0] != run[-1][0] + CHUNK:
                break
            bases = [(h - o) for o, h in run] + [matches[j][1] - matches[j][0]]
            if max(bases) - min(bases) > 32:
                break
            run.append(matches[j])
        if len(run) >= 3 and run[-1][0] - run[0][0] >= 64:
            bases = sorted(h - o for o, h in run)
            runs.append((run[0][0], bases[len(bases) // 2], len(run)))
    # dedupe identical bases, keep earliest start
    seen: dict[int, tuple[int, int, int]] = {}
    for start, base, length in sorted(runs):
        seen.setdefault(base, (start, base, length))
    return sorted(seen.values())


def size_ok(size: int | None, ref_size: int | None, tol: float = 0.15) -> bool:
    return (
        size is not None
        and ref_size is not None
        and abs(size - ref_size) / max(ref_size, 1) <= tol
    )


def locate_entry(blob: bytes, spec: dict, r2: R2, delta: int) -> tuple[int, list[str]]:
    """Find a function entry in the new binary; evidence returned for review."""
    name = spec["name"]
    body = bytes.fromhex(spec["func_body"])
    ref_size = spec.get("func_size")
    ref_first4 = body[:4]
    ev: list[str] = []

    support: dict[int, list[str]] = {}
    for start, length in ENTRY_WINDOWS:
        masked = mask_bytes(body[start:start + length])
        if fixed_count(masked) < 40:
            continue
        for h in find_all(blob, masked, cap=6):
            support.setdefault(h - start, []).append(f"win[{start}:{start + length}]")
    consensus = None
    if support:
        top = max(len(v) for v in support.values())
        winners = [e for e, v in support.items() if len(v) == top]
        if len(winners) == 1:
            consensus = winners[0]
            ev.append(f"consensus 0x{consensus:08x}: {' | '.join(support[consensus])}")
        else:
            raise SystemExit(f"{name}: ambiguous windows: " +
                             ", ".join(f"0x{e:08x}" for e in winners))

    runs = chunk_runs(blob, body)
    ev.append(f"chunks: {len(runs)} run(s) " +
              ", ".join(f"off+{s}/base=0x{b:08x}/x{n}" for s, b, n in runs)
              if runs else "chunks: no runs")

    def probe(e: int) -> str:
        size = r2.func_size(e + delta) if r2.mode != "unavailable" else None
        bound = prev_is_boundary(blob, e)
        return (f"0x{e:08x} {bound or 'prev=?'} "
                f"r2size={size} first4={blob[e:e + 4].hex()}")

    # 1. consensus entry already at a boundary -> done
    if consensus is not None and prev_is_boundary(blob, consensus):
        ev.append("probe " + probe(consensus))
        size = r2.func_size(consensus + delta) if r2.mode != "unavailable" else None
        if size_ok(size, ref_size):
            return consensus, ev + [f"=> chose 0x{consensus:08x}"]
        ev.append("WARNING: size mismatch, continuing")

    # 2. walk back from consensus (grown-prologue case: body aligns after entry)
    if consensus is not None:
        for p in range(consensus - 1, max(consensus - 17, -1), -1):
            if not prev_is_boundary(blob, p):
                continue
            size = r2.func_size(p + delta) if r2.mode != "unavailable" else None
            score = prefix_best(blob, p, body)
            ev.append(f"walk {probe(p)} prefix={score:.2f}")
            if size_ok(size, ref_size) and score >= 0.70:
                return p, ev + [f"=> walked back to 0x{p:08x}"]
        ev.append("walk-back found nothing; keeping consensus")
        return consensus, ev + [f"=> chose 0x{consensus:08x} (UNVERIFIED-SIZE)"]

    # 3. forward scan from chunk runs, earliest first (rewritten-entry case)
    for start_off, base, _n in runs:
        scanned = 0
        for e in range(base, min(base + 65, len(blob) - 8)):
            if not prev_is_boundary(blob, e):
                continue
            scanned += 1
            size = r2.func_size(e + delta) if r2.mode != "unavailable" else None
            if blob[e:e + 4] == ref_first4 and size_ok(size, ref_size):
                ev.append(f"fwdscan run+{start_off} " + probe(e) + " shape=YES")
                return e, ev + [f"=> chose 0x{e:08x}"]
        ev.append(f"forward scan run+{start_off} base=0x{base:08x}: "
                  f"{scanned} boundary positions, no entry shape")
        for e in range(base, min(base + 65, len(blob) - 8)):
            if not prev_is_boundary(blob, e):
                continue
            size = r2.func_size(e + delta) if r2.mode != "unavailable" else None
            if size_ok(size, ref_size):
                ev.append("fwdscan-relaxed " + probe(e))
                return e, ev + [f"=> chose 0x{e:08x} (RELAXED: shape differs)"]

    raise SystemExit(f"FAILED to locate entry {name}: {'; '.join(ev)}")


def context_score(blob: bytes, at_call: int, before_hex: str, after_hex: str) -> float:
    """Fraction of *fixed* (non-RIP-relative) context bytes matching."""
    before, after = bytes.fromhex(before_hex), bytes.fromhex(after_hex)
    masked = mask_bytes(before + b"\xe8\x00\x00\x00\x00" + after)
    base = at_call - len(before)
    if base < 0 or base + len(masked) > len(blob):
        return 0.0
    fixed = total = 0
    for i, m in enumerate(masked):
        if m is None:
            continue
        total += 1
        if blob[base + i] == m:
            fixed += 1
    return fixed / total if total else 0.0


def locate_nops(blob: bytes, anchor: int, nop_specs: list[dict]) -> tuple[dict[str, int], list[str]]:
    """Locate nop-call sites; verify each resolves to the anchor entry."""
    report: list[str] = []
    found: dict[str, int] = {}
    callers = callers_of(blob, anchor)
    report.append(f"anchor 0x{anchor:08x} has {len(callers)} callers")
    for spec in nop_specs:
        name = spec["name"]
        before, after = bytes.fromhex(spec["context_before"]), bytes.fromhex(spec["context_after"])
        hit = None
        for pre, post in NOP_WINDOWS:
            # e8 opcode stays fixed; mask_bytes wildcards only its rel32.
            pat = mask_bytes(before[pre:] + b"\xe8\x00\x00\x00\x00" + after[:post])
            hits = [h + len(before[pre:]) for h in find_all(blob, pat, cap=6)]
            hits = [h for h in hits if blob[h] == 0xE8]
            if len(hits) == 1:
                hit = hits[0]
                report.append(f"{name}: direct window({pre}:+{post}) -> 0x{hit:08x}")
                break
        if hit is None:
            scored = sorted(
                ((context_score(blob, c, spec["context_before"], spec["context_after"]), c)
                 for c in callers),
                reverse=True,
            )
            top = scored[:4]
            log(f"[nop:{name}] fallback scores " +
                ", ".join(f"0x{c:08x}={s:.3f}" for s, c in top))
            report.append(f"{name}: fallback, best 0x{top[0][1]:08x}={top[0][0]:.3f}")
            if top and top[0][0] >= 0.90 and top[0][1] not in found.values():
                hit = top[0][1]
        if hit is None:
            raise SystemExit(f"FAILED to locate nop site {name}")
        rel = struct.unpack_from("<i", blob, hit + 1)[0]
        if hit + 5 + rel != anchor:
            raise SystemExit(
                f"nop site {name} @0x{hit:08x} calls 0x{hit + 5 + rel:08x}, "
                f"not anchor 0x{anchor:08x}")
        report.append(f"{name}: 0x{hit:08x} calls anchor OK")
        found[name] = hit
    if len(set(found.values())) != len(found):
        raise SystemExit(f"nop sites collided: {found}")
    return found, report


# --------------------------------------------------------------------------
# tarball handling
# --------------------------------------------------------------------------

def fetch_tarball(url_or_path: str, version: str) -> tuple[bytes, str, str]:
    """Return (binary_bytes, sha256hex, sha256nix32)."""
    if os.path.isfile(url_or_path):
        log(f"[dl] using local file {url_or_path}")
        with open(url_or_path, "rb") as f:
            raw = f.read()
        url = url_or_path
    else:
        os.makedirs(CACHE_DIR, exist_ok=True)
        cached = os.path.join(CACHE_DIR, f"sublime_text_build_{version}_x64.tar.xz")
        if os.path.isfile(cached):
            log(f"[dl] using cached {cached}")
            with open(cached, "rb") as f:
                raw = f.read()
        else:
            log(f"[dl] downloading {url_or_path}")
            with urllib.request.urlopen(url_or_path, timeout=300) as r:
                raw = r.read()
            with open(cached, "wb") as f:
                f.write(raw)
        url = url_or_path
    digest = hashlib.sha256(raw).hexdigest()
    log(f"[dl] sha256: {digest}")
    for member_name in ("sublime_text/sublime_text", "./sublime_text/sublime_text"):
        try:
            import io
            with tarfile.open(fileobj=io.BytesIO(raw)) as tf:
                m = tf.getmember(member_name)
                with tf.extractfile(m) as f:
                    return f.read(), digest, url
        except KeyError:
            continue
    raise SystemExit("sublime_text binary not found in tarball")


def nix32(hex_digest: str) -> str:
    out = subprocess.run(
        ["nix", "hash", "convert", "--to", "nix32", "--hash-algo", "sha256", hex_digest],
        capture_output=True, text=True, timeout=60,
    )
    if out.returncode != 0:
        raise SystemExit(f"nix hash convert failed: {out.stderr.strip()}")
    return out.stdout.strip()


# --------------------------------------------------------------------------
# update command
# --------------------------------------------------------------------------

def _write_temp(blob: bytes, version: str) -> str:
    """Spill the binary to the cache dir so radare2 can open it by path."""
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = os.path.join(CACHE_DIR, f"sublime_text_{version}")
    with open(path, "wb") as f:
        f.write(blob)
    return path


def cmd_update(args: argparse.Namespace) -> int:
    with open(args.json_path) as f:
        db = json.load(f)
    try:
        ref = db["versions"][args.ref_version]
    except KeyError:
        raise SystemExit(f"no entry for ref version {args.ref_version} in {args.json_path}")

    blob, digest, url = fetch_tarball(args.tarball, args.new_version)
    delta = exec_delta(blob)
    log(f"[elf] exec fileoff->vaddr delta: +0x{delta:x}")

    r2 = R2(_write_temp(blob, args.new_version))
    try:
        # anchor first: nop sites must resolve to it
        anchor_body = ref["validation"]["body"]
        anchor, anchor_ev = locate_anchor(blob, anchor_body)
        if anchor is None:
            raise SystemExit(f"anchor not found: {anchor_ev}")
        log(f"[anchor] validation -> 0x{anchor:08x} ({anchor_ev})")

        new_entry: dict = {
            "build": args.new_version,
            "url": url if url.startswith("http") else
                   f"https://download.sublimetext.com/sublime_text_build_{args.new_version}_x64.tar.xz",
            "sha256hex": digest,
            "sha256": nix32(digest),
            "based_on": f"retargeted from {args.ref_version} via gen_patches.py",
            "mapping": {},
            "validation": {},
            "patches": [],
        }

        # nop sites (need anchor)
        nop_specs = [p for p in ref["patches"] if p["kind"] == "nop-call"]
        nop_hits, nop_report = locate_nops(blob, anchor, nop_specs)
        for line in nop_report:
            log(f"[nop] {line}")

        # entry patches
        entry_specs = [p for p in ref["patches"] if p["kind"] == "entry-ret0"]
        entry_hits: dict[str, int] = {}
        for spec in entry_specs:
            name = spec["name"]
            entry, ev = locate_entry(blob, spec, r2, delta)
            for line in ev:
                log(f"[entry:{name}] {line}")
            entry_hits[name] = entry

        # build the new entry (snapshot pristine bytes as `original`)
        vsize = r2.func_size(anchor + delta) if r2.mode != "unavailable" else None
        new_entry["validation"] = {
            "offset": f"{anchor:08x}",
            "func_size": vsize,
            "body": blob[anchor:anchor + 220].hex(),
        }
        new_entry["mapping"]["validation"] = [ref["validation"]["offset"], f"0x{anchor:x}"]
        for spec in ref["patches"]:
            name = spec["name"]
            off = nop_hits[name] if spec["kind"] == "nop-call" else entry_hits[name]
            ln = spec["length"]
            new_entry["mapping"][name] = [f"0x{int(spec['offset'], 16):x}", f"0x{off:x}"]
            new_spec = dict(spec)
            new_spec["offset"] = f"{off:08x}"
            new_spec["original"] = blob[off:off + ln].hex()
            new_spec["comment"] = (
                f"retargeted from {args.ref_version} "
                f"0x{int(spec['offset'], 16):x} -> 0x{off:x}")
            if spec["kind"] == "nop-call":
                new_spec["context_before"] = blob[off - 48:off].hex()
                new_spec["context_after"] = blob[off + 5:off + 21].hex()
            else:
                new_spec["func_body"] = blob[off:off + 1024].hex()
                new_spec["func_size"] = (
                    r2.func_size(off + delta) if r2.mode != "unavailable" else None)
            new_entry["patches"].append(new_spec)

        print("\n--- new entry ---")
        print(json.dumps(new_entry, indent=2))
        print("\n--- xxd lines ---")
        for p in new_entry["patches"]:
            print(f"echo '{p['offset']}: {p['patched']}' | xxd -r - sublime_text   # {p['name']}")
        print("\n--- default.nix ---")
        print(f'    buildVersion = "{args.new_version}";')
        print(f"      sha256 = \"{new_entry['sha256']}\";")

        if args.write:
            if args.new_version in db["versions"] and not args.force:
                raise SystemExit(
                    f"{args.new_version} already in {args.json_path} (use --force)")
            db["versions"][args.new_version] = new_entry
            with open(args.json_path, "w") as f:
                json.dump(db, f, indent=2)
                f.write("\n")
            log(f"[write] entry {args.new_version} stored in {args.json_path}")
        return 0
    finally:
        r2.close()


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)
    up = sub.add_parser("update", help="retarget patches to a new build")
    up.add_argument("--ref-version", required=True, help="reference entry in patches.json")
    up.add_argument("--new-version", required=True, help="new build number")
    up.add_argument("--tarball", required=True, help="new tarball URL or local path")
    up.add_argument("--json-path", default=DEFAULT_JSON)
    up.add_argument("--write", action="store_true", help="store new entry in patches.json")
    up.add_argument("--force", action="store_true", help="overwrite existing entry")
    return ap


def main() -> int:
    args = build_parser().parse_args()
    if args.cmd == "update":
        return cmd_update(args)
    return 1


if __name__ == "__main__":
    sys.exit(main())
