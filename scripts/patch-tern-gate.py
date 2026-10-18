#!/usr/bin/env python3
"""Remove Tern's remote startup login flow by patching the installed binary.

The closed-beta gate is driven by a small account state machine in the Tern
window process. At startup it runs a "check saved sign-in" step which sets
``phase = reading(1)``, touches the system keychain, and later flips the
phase to ``signed-out(2)``, which renders the blocking sign-in veil.

This script neuters that flow with three minimal patches (x86_64),
plus one for the omp manager's offer gate (same event-driven pattern):

  P1: gate startup fn ..... phase = reading(1) -> off(0)
  P2: gate completion fn ... phase = signed-out(2) -> off(0)
  P3: gate startup fn entry  -> early return, so the gate is never armed,
      the keychain/saved session is never read, and the account worker is
      never asked to do anything.
  P4: omp offer gate ........ jne -> jmp, so the "let Tern keep omp up to
      date?" veil is never rendered.

Sites are located by fingerprint variants: exact opcode and immediate
bytes, with struct/stack displacements wildcarded (they shift with every
build) and cross-field consistency enforced via regex backrefs plus per-
variant validators (e.g. the phase field must appear with the same offset
in the cmp and the immediate store; the keychain slot must sit at
phase+0x10).  When upstream only moves struct fields - which is what
broke the 0.8.4 fingerprints on 0.9.2 - the same variant keeps matching.
When upstream changes codegen shape, add a new variant for the new shape
next to the old one, so a single script covers every known version.

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


def validate_gate_start(captures):
    """Account-state layout relations observed in 0.8.4 and 0.9.2.

    The phase enum is followed by a presence flag at +8 and the keychain
    slot at +0x10; both builds agree, so a match violating this points at
    the wrong site.
    """
    phase = captures["phase"]
    _expect(phase >= 0x400, f"gate-start: phase offset {phase:#x} implausibly small")
    _expect(
        captures["session_check"] == phase + 8,
        f"gate-start: session check at {captures['session_check']:#x}, "
        f"expected phase+8 ({phase + 8:#x})",
    )
    _expect(
        captures["keychain"] == phase + 0x10,
        f"gate-start: keychain slot at {captures['keychain']:#x}, "
        f"expected phase+0x10 ({phase + 0x10:#x})",
    )


def validate_gate_complete(captures):
    """Same layout relations plus session = phase+0x20 (both builds)."""
    phase = captures["phase"]
    session = captures["session"]
    _expect(phase >= 0x400, f"gate-complete: phase offset {phase:#x} implausibly small")
    _expect(
        session == phase + 0x20,
        f"gate-complete: session at {session:#x}, "
        f"expected phase+0x20 ({phase + 0x20:#x})",
    )
    _expect(
        captures["session_end"] == session + 0x10,
        f"gate-complete: session tail at {captures['session_end']:#x}, "
        f"expected session+0x10 ({session + 0x10:#x})",
    )
    _expect(
        captures["phase_check"] == phase + 8,
        f"gate-complete: phase recheck at {captures['phase_check']:#x}, "
        f"expected phase+8 ({phase + 8:#x})",
    )
    _expect(
        captures["phase_keychain"] == phase + 0x10,
        f"gate-complete: keychain slot at {captures['phase_keychain']:#x}, "
        f"expected phase+0x10 ({phase + 0x10:#x})",
    )


def validate_omp_flag(captures):
    _expect(
        captures["flag"] >= 0x400,
        f"omp-offer: flag offset {captures['flag']:#x} implausibly small",
    )


# P3: xor eax,eax; ret, nop-padded over the 10-byte gate-start prologue.
EARLY_RETURN = bytes.fromhex("31c0c3") + b"\x90" * 7

# Patch sites: name -> tuple of known codegen variants (0.8.4 and 0.9.2
# verified).  Exactly one variant must match exactly once.
SITES = {
    # Gate startup fn: prologue, arm flag, phase check, phase = 1, keychain
    # read.  Struct offsets (arm/phase/session/keychain) move between
    # builds - 0.8.4 used 0xc58/0xb78/0xb80/0xb88, 0.9.2 0x5378/0x5288/
    # 0x5290/0x5298 - so they are captured and validated, not hardcoded.
    # The backref forces the cmp and the immediate store to agree on the
    # phase offset.
    "gate-start": (
        variant(
            label="entry/phase/keychain shape (0.8.4, 0.9.2)",
            pattern=(
                "41 56 53 48 83 ec 18 48 89 fb"
                " c6 87 (?P<arm>.{4}) 01"
                " 83 bf (?P<phase>.{4}) 05 72 17"
                " 48 83 bb (?P<session_check>.{4}) 00 74 0d"
                " 48 8b bb (?P<keychain>.{4})"
                " ff 15 ?? ?? ?? ??"
                " 48 c7 83 (?P=phase) 01 00 00 00"
                " 48 89 e7"
                " ff 15 ?? ?? ?? ??"
            ),
            patches=((56, 0x00),),  # P1: phase = reading(1) -> off(0)
            entry=EARLY_RETURN,  # P3
            validate=validate_gate_start,
        ),
    ),
    # Gate completion fn: session copy, phase == 0 -> phase = 2.  Same
    # account-state offsets as gate-start plus the session copy at
    # phase+0x20; backrefs pin the repeated fields.
    "gate-complete": (
        variant(
            label="session/phase shape (0.8.4, 0.9.2)",
            pattern=(
                "0f 10 83 (?P<session>.{4})"
                " 0f 10 8b (?P<session_end>.{4})"
                " 0f 29 4c 24 10 0f 29 04 24"
                " 48 c7 83 (?P=session) 00 00 00 00"
                " 4c 8d b3 (?P<phase>.{4})"
                " 83 bb (?P=phase) 05 72 17"
                " 48 83 bb (?P<phase_check>.{4}) 00 74 0d"
                " 48 8b bb (?P<phase_keychain>.{4})"
                " ff 15 ?? ?? ?? ??"
                " 0f 28 04 24 0f 28 4c 24 10"
                " 41 0f 11 4e 10 41 0f 11 06"
                " 49 83 3e 00 75 07"
                " 49 c7 06 02 00 00 00"
                " 48 89 df"
                " ff 15 ?? ?? ?? ??"
            ),
            patches=((100, 0x00),),  # P2: phase = signed-out(2) -> off(0)
            validate=validate_gate_complete,
        ),
    ),
    # Omp offer gate: event != sentinel and runtime flag == 0 -> build the
    # offer UI.  0.8.4 kept the event in a stack slot and the flag on the
    # app struct in r14; 0.9.2 hoisted the event into rbp, moved the flag
    # to rbx+0xce0 and scheduled a load between the cmp and the jne.  Both
    # shapes share the same fix: flip the fall-through jne to jmp.
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
            "struct offsets wildcarded and validated) or the gate was "
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

    # Both gate fns poke the same account-state field; a disagreement means
    # one of the matches landed on an impostor site.
    start_phase = resolved["gate-start"][2]["phase"]
    complete_phase = resolved["gate-complete"][2]["phase"]
    if start_phase != complete_phase:
        raise RuntimeError(
            f"gate-start phase {start_phase:#x} != gate-complete phase "
            f"{complete_phase:#x}; the fingerprints disagree on the "
            "account-state layout - refusing to patch"
        )

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
    print(f"{args.binary}: startup login flow removed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
