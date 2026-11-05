#!/usr/bin/env python3
"""Neuter Tern's omp management offer by patching the installed binary.

Up to 0.9.9 Tern also had a blocking startup sign-in gate. That state machine
and its UI strings ("Closed beta", "your keyring", "tn-gate-wait") are gone
from 0.9.12; the remaining sign-in card is the non-blocking first-start card,
so the gate patches (P1-P3) were dropped. Only the omp offer gate remains:

  P4: omp offer gate ........ jne -> jmp, so the "let Tern keep omp up to
      date?" veil is never rendered.

Sites are located by fingerprint variants: exact opcode and immediate
bytes, with struct/stack displacements wildcarded (they shift with every
build) and cross-field consistency enforced via regex backrefs plus
per-variant validators (e.g. the flag must sit at a plausible struct
offset).  When upstream moves struct fields, the same variant keeps
matching; when upstream changes codegen shape, add a new variant for the
new shape next to the old one, so a single script covers every known
version.

Every site must be matched by exactly one variant exactly once, and every
variant that does not match must match zero times, or the script aborts
without writing anything: an unknown codegen change can never ship
unpatched silently.
"""

import argparse
import re
import struct
import sys
from pathlib import Path


WILD = "??"


def to_regex(hex_pattern):
    """Turn 'AA BB ?? (?P<name>.{4}) (?P=name)' into a bytes regex.

    ``??`` matches a single wildcard byte (used for rip-relative
    displacements); ``(?P<...>...)`` tokens pass through verbatim so the
    pattern can capture struct offsets and back-reference them.
    """
    out = b""
    for part in hex_pattern.split():
        if part == WILD:
            out += b"."
        elif part.startswith("(?P"):
            out += part.encode()
        else:
            out += re.escape(bytes([int(part, 16)]))
    return re.compile(out, re.DOTALL)


def variant(label, pattern, patches=(), entry=None, validate=None):
    """One known codegen shape of a patch site.

    patches:  tuple of (byte offset within the match, new byte)
    entry:    replacement bytes for the first len(entry) bytes of the match
    validate: optional callable(dict of captured disp32s) -> None; raises
              RuntimeError when the captured offsets are inconsistent
    """
    return {
        "label": label,
        "pattern": pattern,
        "patches": patches,
        "entry": entry,
        "validate": validate,
    }


def _expect(cond, message):
    if not cond:
        raise RuntimeError(message)


def validate_omp_flag(captures):
    _expect(
        captures["flag"] >= 0x400,
        f"omp-offer: flag offset {captures['flag']:#x} implausibly small",
    )


# Patch sites: name -> tuple of known codegen variants (0.8.4, 0.9.2 and
# 0.9.12 verified).  Exactly one variant must match exactly once.
SITES = {
    # Omp offer gate: event != sentinel and runtime flag == 0 -> build the
    # offer UI.  0.8.4 kept the event in a stack slot and the flag on the
    # app struct in r14; 0.9.2 hoisted the event into rbp, moved the flag
    # to rbx+0xce0 and scheduled a load between the cmp and the jne.
    # 0.9.12 returns to the 0.8.4 shape but marks the flag handled before
    # building the UI, adding a store between the jne and the event load.
    # All shapes share the same fix: flip the fall-through jne to jmp.
    "omp-offer": (
        variant(
            label="stack-event/r14-flag shape (0.8.4)",
            pattern=(
                "48 83 bc 24 (?P<event>.{4}) fe 74 ??"
                " 41 80 be (?P<flag>.{4}) 00 75 ??"
                " 48 8d b4 24 (?P=event)"
                " 48 8d 7c 24 ??"
                " ff 15 ?? ?? ?? ??"
            ),
            patches=((19, 0xEB),),  # P4: jne -> jmp
            validate=validate_omp_flag,
        ),
        variant(
            label="rbp-event/rbx-flag shape (0.9.2)",
            pattern=(
                "48 83 fd fe 75 ??"
                " 48 8b 44 24 (?P<slot>.)"
                " e9 ?? ?? ?? ??"
                " 80 bb (?P<flag>.{4}) 00"
                " 48 8b 44 24 (?P=slot)"
                " 75 ??"
                " 48 8d b4 24 ?? ?? ?? ??"
            ),
            patches=((28, 0xEB),),  # P4: jne -> jmp
            validate=validate_omp_flag,
        ),
        variant(
            label="stack-event/r14-flag/handled shape (0.9.12)",
            pattern=(
                "48 83 bc 24 (?P<event>.{4}) fe 74 ??"
                " 41 80 be (?P<flag>.{4}) 00 75 ??"
                " 48 8d b4 24 (?P=event)"
                " 41 c6 86 (?P=flag) 01"
                " 48 8d 7c 24 ??"
                " ff 15 ?? ?? ?? ??"
            ),
            patches=((19, 0xEB),),  # P4: jne -> jmp
            validate=validate_omp_flag,
        ),
    ),
}


def find_variant(data, site_name, variants):
    """Resolve a site to a single unambiguous variant match.

    Returns (variant, match_offset, captured_disp32s).  Aborts unless
    exactly one variant matches exactly once and all others match zero
    times.
    """
    unambiguous = []
    diagnostics = []
    loose = []
    for candidate in variants:
        matches = list(to_regex(candidate["pattern"]).finditer(data))
        diagnostics.append(f"{candidate['label']}: {len(matches)}")
        if len(matches) == 1:
            unambiguous.append((candidate, matches[0]))
        elif len(matches) > 1:
            loose.append(candidate["label"])
    if len(unambiguous) != 1 or loose:
        hint = (
            "the binary differs from the analyzed builds. Either upstream "
            "changed the codegen (add a fingerprint variant for the new "
            "shape to SITES in scripts/patch-tern-gate.py, keeping the "
            "struct offsets wildcarded and validated) or the offer was "
            "removed upstream (drop the patch)"
        )
        if loose:
            raise RuntimeError(
                f"fingerprint {site_name}: over-generic variant(s) matched "
                f"multiple times ({', '.join(loose)}); {hint}"
            )
        raise RuntimeError(
            f"fingerprint {site_name}: expected exactly 1 variant with "
            f"exactly 1 match, found {len(unambiguous)} "
            f"[{', '.join(diagnostics)}]; {hint}"
        )
    candidate, match = unambiguous[0]
    captures = {}
    for name in match.groupdict():
        raw = match.group(name)
        # Backref-only captures (e.g. a 1-byte stack slot) are kept raw;
        # validators only ever look at 4-byte struct displacements.
        captures[name] = (
            struct.unpack("<I", raw)[0] if len(raw) == 4 else raw
        )
    if candidate["validate"] is not None:
        try:
            candidate["validate"](captures)
        except RuntimeError as error:
            raise RuntimeError(
                f"fingerprint {site_name} ({candidate['label']}): {error}"
            ) from None
    return candidate, match.start(), captures


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

    resolved = {}
    for name, variants in SITES.items():
        resolved[name] = find_variant(data, name, variants)

    edits = []
    for name, (candidate, at, _captures) in resolved.items():
        for offset, new_byte in candidate["patches"]:
            edits.append((at + offset, data[at + offset], new_byte))
        if candidate["entry"] is not None:
            entry = candidate["entry"]
            # The pattern pins these bytes exactly, so this can only fail
            # if the file changed under us.
            edits.append((at, bytes(data[at:at + len(entry)]), entry))

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
    print(f"{args.binary}: omp management offer removed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
