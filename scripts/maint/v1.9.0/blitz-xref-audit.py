#!/usr/bin/env python3
"""Cross-reference rot audit for the blitz skill suite (v2).

Improvements over v1:
- Skip fenced code blocks (``` and ~~~) and inline code (`...`)
- Skip lines that look like template placeholders ({var}, <var>)
- Add Phase number reference verification
- Add bare-filename "see X.md" reference verification
- Tighter false-positive control on suspect heuristics
"""
import re
import sys
import pathlib
from collections import defaultdict

ROOT = pathlib.Path("/home/tom/development/blitz")
SKILL_SHARED = ROOT / "skills" / "_shared"

SCAN_PATTERNS = [
    "skills/**/*.md",
    "hooks/**/*.md",
    ".claude-plugin/*.json",
    "CLAUDE.md",
    "README.md",
]


def resolve_link(link, source_file):
    if "#" in link:
        path_part, anchor = link.split("#", 1)
    else:
        path_part, anchor = link, None
    path_part = path_part.split("?", 1)[0]
    if not path_part:
        return source_file, anchor
    if path_part.startswith("/_shared/"):
        return SKILL_SHARED / path_part[len("/_shared/"):], anchor
    if path_part.startswith("/"):
        return ROOT / path_part.lstrip("/"), anchor
    if path_part.startswith(("http://", "https://", "mailto:")):
        return None, None
    return (source_file.parent / path_part).resolve(), anchor


def slugify(heading):
    h = heading.strip().lower()
    h = re.sub(r'[^\w\s-]', '', h)
    h = re.sub(r'\s+', '-', h)
    return h


def read_headings(path):
    if not path.exists() or path.is_dir():
        return set()
    try:
        text = path.read_text(errors="replace")
    except Exception:
        return set()
    headings = set()
    in_fence = False
    for line in text.splitlines():
        if re.match(r'^\s*(```|~~~)', line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        m = re.match(r'^#{1,6}\s+(.+?)\s*$', line)
        if m:
            headings.add(slugify(m.group(1)))
    return headings


def strip_code(text):
    """Return text with fenced code blocks and inline code removed (line-aligned)."""
    out_lines = []
    in_fence = False
    for line in text.splitlines():
        if re.match(r'^\s*(```|~~~)', line):
            in_fence = not in_fence
            out_lines.append("")  # keep line numbers
            continue
        if in_fence:
            out_lines.append("")
            continue
        # Strip inline code
        out_lines.append(re.sub(r'`[^`]*`', '', line))
    return out_lines


def scan_files():
    files = []
    for pat in SCAN_PATTERNS:
        for f in ROOT.glob(pat):
            if f.is_file():
                files.append(f)
    return sorted(set(files))


LINK_RE = re.compile(r'(?<!\!)\[([^\]]+)\]\(([^)]+)\)')

broken = defaultdict(list)
suspect = defaultdict(list)


def is_template(s):
    """Detect template-like strings: {var}, <var>, ALL_CAPS_PATH, has braces, etc."""
    if re.search(r'\{[^}]+\}', s):
        return True
    if re.search(r'<[A-Z_]+>', s):
        return True
    # bare ALL_CAPS path-like tokens are usually templates
    if re.match(r'^[A-Z_]+(/[A-Z_]+)+$', s):
        return True
    return False


def scan_links(source):
    if source.suffix not in (".md", ".json"):
        return
    try:
        text = source.read_text(errors="replace")
    except Exception:
        return

    if source.suffix == ".md":
        scan_lines = strip_code(text)
    else:
        scan_lines = text.splitlines()

    for lineno, line in enumerate(scan_lines, 1):
        for m in LINK_RE.finditer(line):
            link_text = m.group(1)
            link_url = m.group(2)
            if is_template(link_url):
                continue
            target, anchor = resolve_link(link_url, source)
            if target is None:
                continue
            if not target.exists():
                broken[source].append((lineno, link_text, link_url, f"target file missing: {target}"))
                continue
            if anchor:
                headings = read_headings(target)
                if anchor not in headings:
                    matches = [h for h in headings if anchor in h or h in anchor]
                    if matches:
                        suspect[source].append((lineno, link_text, link_url, f"anchor '#{anchor}' not exact; near: {matches[:2]}"))
                    else:
                        broken[source].append((lineno, link_text, link_url, f"anchor '#{anchor}' not found in {target.name}"))


def scan_phase_refs(source):
    """Detect phase-number references that may have shifted after Phase 0.0 input gate insertion."""
    if source.suffix != ".md":
        return
    try:
        text = source.read_text(errors="replace")
    except Exception:
        return
    scan_lines = strip_code(text)
    # Find references to phases in OTHER skills (e.g., "sprint-plan Phase 0 step 8")
    # If sprint-plan now has Phase 0.0 (input gate), references to its "Phase 0" may be ambiguous
    for lineno, line in enumerate(scan_lines, 1):
        # Cross-skill phase refs
        m = re.findall(r'\b(sprint-plan|sprint-dev|sprint-review)\b[^\n]{0,60}\bPhase\s+(\d+(?:\.\d+)?)', line)
        for skill, phase in m:
            # If we're in sprint-* SKILL.md, this might be a self-ref; skip
            if source.parent.name == skill:
                continue
            # Flag for manual verification — phase refs are easy to drift
            suspect[source].append((lineno, "(phase ref)", f"{skill} Phase {phase}", "verify phase still exists at this number"))


def scan_bare_section_refs(source):
    """Detect 'see <doc>.md section X' bare references."""
    if source.suffix != ".md":
        return
    try:
        text = source.read_text(errors="replace")
    except Exception:
        return
    scan_lines = strip_code(text)
    for lineno, line in enumerate(scan_lines, 1):
        # "reference.md section ..." or similar bare refs
        m = re.search(r'`?(\w+/reference\.md|reference\.md|[\w-]+\.md)`?\s+(?:section|§)\s+\*\*?"?([^*"\n]+?)"?\*\*?', line)
        if m:
            doc, section = m.group(1), m.group(2).strip()
            # Resolve doc
            if "/" in doc:
                target = ROOT / "skills" / doc
            else:
                target = source.parent / doc
            if target.exists():
                headings = read_headings(target)
                if slugify(section) not in headings:
                    matches = [h for h in headings if slugify(section) in h or h in slugify(section)]
                    if matches:
                        suspect[source].append((lineno, "(bare section)", f"{doc} §{section}", f"near: {matches[:2]}"))
                    else:
                        broken[source].append((lineno, "(bare section)", f"{doc} §{section}", f"section not found in {target.name}"))
            else:
                broken[source].append((lineno, "(bare section)", f"{doc}", f"target file missing: {target}"))


# Main
files = scan_files()
print(f"Scanning {len(files)} files...", file=sys.stderr)
for f in files:
    scan_links(f)
    scan_phase_refs(f)
    scan_bare_section_refs(f)

total_broken = sum(len(v) for v in broken.values())
total_suspect = sum(len(v) for v in suspect.values())

print(f"\n=== BROKEN ({total_broken}) ===")
for src in sorted(broken):
    rel = src.relative_to(ROOT)
    for lineno, text, link, reason in broken[src]:
        print(f"  {rel}:{lineno}  [{text}]({link})")
        print(f"    → {reason}")

print(f"\n=== SUSPECT ({total_suspect}) ===")
for src in sorted(suspect):
    rel = src.relative_to(ROOT)
    for lineno, text, link, reason in suspect[src]:
        print(f"  {rel}:{lineno}  [{text}]({link})")
        print(f"    → {reason}")

print(f"\nDone. {total_broken} broken, {total_suspect} suspect across {len(files)} files.")
sys.exit(1 if total_broken else 0)
