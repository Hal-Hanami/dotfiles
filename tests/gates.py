#!/usr/bin/env python3
"""Repository-wide gates that the shell suite cannot express.

These are checks over the whole tracked file set rather than over behaviour, so they
live here instead of in bats: matching section numbers across files and sweeping every
tracked file for vocabulary are jobs for a regex engine, not for shell.

Run with no arguments; exits non-zero on the first class of failure with the offending
locations named. CI runs exactly this, so a green local run means a green build.
"""

import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DESIGN = ROOT / "docs" / "DESIGN.md"
README = ROOT / "README.md"
MANIFEST = ROOT / "tests" / "expected-tools.txt"

# This file has to spell out the words it bans and the alphabet it rejects.
SELF = "tests/gates.py"

# Vocabulary that describes the author's plans rather than the system. Every entry
# reached a published file in a repository of this author's before being removed.
PLANNING = re.compile(
    r"pillar\s*[1-4]|柱\s*[1-4]|recruiter|portfolio|talking\s*point"
    r"|面接|履歴書|職務経歴|ビルド[①-⑨]|\bM[1-7]\b",
    re.I,
)
JAPANESE = re.compile(r"[぀-ゟ゠-ヿ一-鿿]")

# The Japanese README exists on purpose: the English one is the entry point and this
# is an addition, not a replacement.
JAPANESE_ALLOWED = {"README.ja.md", SELF}


def tracked():
    out = subprocess.run(
        ["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, check=True
    )
    return out.stdout.split()


def read(rel):
    try:
        return (ROOT / rel).read_text(encoding="utf-8")
    except (UnicodeDecodeError, IsADirectoryError, FileNotFoundError):
        return None


def fail(msg, items):
    print(f"FAIL: {msg}", file=sys.stderr)
    for i in items:
        print(f"  {i}", file=sys.stderr)
    sys.exit(1)


def block(text, name):
    """Extract a region the documentation marks as machine-checked."""
    m = re.search(rf"<!-- BEGIN {name} -->(.*?)<!-- END {name} -->", text, re.S)
    if not m:
        fail(f"README.md has no '{name}' block to check against", [])
    return m.group(1)


def gate_sections_defined():
    design = DESIGN.read_text(encoding="utf-8")
    defined = {int(n) for n in re.findall(r"^## §(\d+)\s", design, re.M)}
    if not defined:
        fail("docs/DESIGN.md declares no numbered sections", [])
    return defined


def gate_sections_pinned(defined):
    tests = "\n".join(
        p.read_text(encoding="utf-8") for p in sorted((ROOT / "tests").iterdir())
        if p.is_file() and p.name != "gates.py"
    )
    # Citing §4.3 counts as citing §4 — a subsection belongs to its section.
    unpinned = [n for n in sorted(defined) if not re.search(rf"§{n}(?!\d)", tests)]
    if unpinned:
        fail(
            "no test cites a design section — a rule nobody checks is one the next "
            "change breaks",
            [f"§{n}" for n in unpinned],
        )
    print(f"ok: all {len(defined)} design sections are pinned by a test")


def gate_sections_resolve(defined):
    # A reader can only resolve a section this repository defines. Numbers pointing
    # at an outside document survive precisely because nothing fails on them.
    dangling = []
    for rel in tracked():
        text = read(rel)
        if text is None:
            continue
        for n in sorted({int(m) for m in re.findall(r"§(\d+)", text)}):
            if n not in defined:
                dangling.append(f"{rel}: §{n}")
    if dangling:
        fail("reference to a section docs/DESIGN.md does not define", dangling)
    print(f"ok: every § reference resolves to one of {len(defined)} sections")


def gate_sweep():
    hits = []
    for rel in tracked():
        text = read(rel)
        if text is None:
            continue
        for i, line in enumerate(text.splitlines(), 1):
            if rel != SELF and PLANNING.search(line):
                hits.append(f"{rel}:{i}: planning vocabulary: {line.strip()[:90]}")
            elif rel not in JAPANESE_ALLOWED and JAPANESE.search(line):
                hits.append(f"{rel}:{i}: not English: {line.strip()[:90]}")
    if hits:
        fail("these read as the author's context, not the system's", hits)
    print(f"ok: swept {len(tracked())} tracked files")


def gate_readme_inventory():
    listed = [
        ln.split()[0]
        for ln in block(README.read_text(encoding="utf-8"), "repo-tree").splitlines()
        if ln.strip() and not ln.strip().startswith("```")
    ]
    actual = tracked()
    missing = sorted(set(actual) - set(listed))
    extra = sorted(set(listed) - set(actual))
    if missing or extra:
        fail(
            "the README inventory is not what the repository contains",
            [f"absent from README: {m}" for m in missing]
            + [f"listed but not tracked: {e}" for e in extra],
        )
    print(f"ok: README lists all {len(actual)} tracked files")


def gate_readme_tools():
    manifest = {
        ln.split()[0]
        for ln in MANIFEST.read_text(encoding="utf-8").splitlines()
        if ln.strip() and not ln.startswith("#")
    }
    documented = set(
        re.findall(r"`([a-z0-9-]+)`", block(README.read_text(encoding="utf-8"), "core-tools"))
    )
    if manifest != documented:
        fail(
            "the README and the core-layer manifest disagree about what is installed",
            [f"manifest only: {t}" for t in sorted(manifest - documented)]
            + [f"README only: {t}" for t in sorted(documented - manifest)],
        )
    print(f"ok: README and manifest agree on {len(manifest)} tools")


def main():
    defined = gate_sections_defined()
    gate_sections_pinned(defined)
    gate_sections_resolve(defined)
    gate_sweep()
    gate_readme_inventory()
    gate_readme_tools()
    print("all gates passed")


if __name__ == "__main__":
    main()
