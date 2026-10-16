#!/usr/bin/env python3
"""Remove Tern's remote startup login flow by patching the installed binary.

The closed-beta gate is driven by a small account state machine in the Tern
window process. At startup it runs a "check saved sign-in" step which sets
``phase = reading(1)``, touches the system keychain, and later flips the
phase to ``signed-out(2)``, which renders the blocking sign-in veil.

This script neuters that flow with three minimal patches (x86_64):

  P1: gate startup fn ..... phase = reading(1) -> off(0)
  P2: gate completion fn ... phase = signed-out(2) -> off(0)
  P3: gate startup fn entry  -> early return, so the gate is never armed,
      the keychain/saved session is never read, and the account worker is
      never asked to do anything.

All sites are located by fingerprints: exact instruction bytes with
wildcards only for rip-relative displacements (which shift between
builds). Register allocation, struct offsets and immediates are matched
exactly, so any codegen change fails loudly instead of patching the
wrong bytes. Re-run against a pristine binary; every fingerprint must
match exactly once or the script aborts without writing anything.
"""

import argparse
import re
import struct
import sys
from pathlib import Path


WILD = "??"


def to_regex(hex_pattern):
    """Turn 'AA BB ?? CC' into a bytes regex."""
    out = b""
    for part in hex_pattern.split():
        out += b"." if part == WILD else re.escape(bytes([int(part, 16)]))
    return re.compile(out, re.DOTALL)


def find_unique(data, pattern, name):
    """Find pattern exactly once in data; return the offset."""
    matches = list(to_regex(pattern).finditer(data))
    if len(matches) != 1:
        raise RuntimeError(
            f"fingerprint {name}: expected exactly 1 match, found "
            f"{len(matches)}; the binary differs from the analyzed builds. "
            "Either upstream changed the codegen (update the fingerprints "
            "in PATTERNS using the same reverse-engineering flow) or the "
            "gate was removed upstream (drop the patch) - refusing to patch"
        )
    return matches[0].start()


def sub_offset(data, match_at, sub_hex):
    """Locate a sub-pattern inside a matched region; return its offset."""
    region = data[match_at:match_at + 256]
    match = to_regex(sub_hex).search(region)
    if match is None:
        raise RuntimeError("sub-pattern vanished inside fingerprint match")
    return match_at + match.start()


# Full context fingerprints. `??` = rip-relative disp32 (shifts per build).
PATTERNS = {
    # Gate startup fn: prologue, arm flag, phase check, phase = 1, keychain read.
    "gate-start": (
        "41 56 53 48 83 ec 18 48 89 fb"
        " c6 87 58 0c 00 00 01"
        " 83 bf 78 0b 00 00 05 72 17"
        " 48 83 bb 80 0b 00 00 00 74 0d"
        " 48 8b bb 88 0b 00 00"
        " ff 15 ?? ?? ?? ??"
        " 48 c7 83 78 0b 00 00 01 00 00 00"
        " 48 89 e7"
        " ff 15 ?? ?? ?? ??"
    ),
    # Gate completion fn: session copy, phase==0 -> phase = 2.
    "gate-complete": (
        "0f 10 83 98 0b 00 00 0f 10 8b a8 0b 00 00"
        " 0f 29 4c 24 10 0f 29 04 24"
        " 48 c7 83 98 0b 00 00 00 00 00 00"
        " 4c 8d b3 78 0b 00 00"
        " 83 bb 78 0b 00 00 05 72 17"
        " 48 83 bb 80 0b 00 00 00 74 0d"
        " 48 8b bb 88 0b 00 00"
        " ff 15 ?? ?? ?? ??"
        " 0f 28 04 24 0f 28 4c 24 10"
        " 41 0f 11 4e 10 41 0f 11 06"
        " 49 83 3e 00 75 07"
        " 49 c7 06 02 00 00 00"
        " 48 89 df"
        " ff 15 ?? ?? ?? ??"
    ),
}

# (site, sub-pattern locating the instruction, imm offset within it, new byte)
PATCHES = [
    ("gate-start", "48 c7 83 78 0b 00 00 01 00 00 00", 7, 0x00),  # P1: 1 -> 0
    ("gate-complete", "49 c7 06 02 00 00 00", 3, 0x00),  # P2: 2 -> 0
]

# (site, replacement bytes for the function entry)
ENTRY_PATCH = ("gate-start", bytes.fromhex("31c0c3") + b"\x90" * 7)  # P3


def patch_binary(path):
    data = bytearray(Path(path).read_bytes())
    if len(data) < 0x40 or data[0:4] != b"\x7fELF":
        raise RuntimeError("not an ELF binary")
    machine = struct.unpack_from("<H", data, 0x12)[0]
    if machine != 0x3E:  # EM_X86_64
        raise RuntimeError(
            f"unsupported ELF machine {machine:#x}; this patcher only "
            "handles x86_64 Tern builds"
        )

    matches = {}
    for name, pattern in PATTERNS.items():
        matches[name] = find_unique(data, pattern, name)

    edits = []
    for site, sub, imm_off, new_byte in PATCHES:
        at = matches[site]
        instr = sub_offset(data, at, sub)
        target = instr + imm_off
        old = data[target]
        edits.append((target, old, new_byte))

    site, entry = ENTRY_PATCH
    at = matches[site]
    old_entry = bytes(data[at:at + len(entry)])
    expected_entry = bytes.fromhex("4156534883ec184889fb")
    if old_entry != expected_entry:
        raise RuntimeError(
            f"entry prologue mismatch at {at:#x}: {old_entry.hex()} "
            "(register allocation changed?) - refusing to patch"
        )
    edits.append((at, old_entry, entry))

    # All checks passed; apply.
    for target, old, new in edits:
        if isinstance(old, int):
            if data[target] != old:
                raise RuntimeError(f"byte changed under us at {target:#x}")
            data[target] = new
        else:
            data[target:target + len(old)] = new

    Path(path).write_bytes(data)
    return edits


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    args = parser.parse_args()
    try:
        edits = patch_binary(args.binary)
    except (RuntimeError, OSError) as error:
        print(f"patch-tern-gate: {error}", file=sys.stderr)
        return 1
    for target, old, new in edits:
        if isinstance(old, int):
            print(f"{args.binary}: {target:#x}: {old:#04x} -> {new:#04x}")
        else:
            print(f"{args.binary}: {target:#x}: {len(old)} bytes replaced")
    print(f"{args.binary}: startup login flow removed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
