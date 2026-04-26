#!/usr/bin/env python3
"""Companion-file restructure — Anthropic-canonical layout.

Moves:
  skills/<name>/reference.md          → skills/<name>/references/main.md
  skills/<name>/reference.md.original → skills/<name>/references/main.md.original
  skills/ui-audit/CHECKS.md           → skills/ui-audit/references/checks.md
  skills/ui-audit/PATTERNS.md         → skills/ui-audit/references/patterns.md
  skills/setup/conflict-catalog.json  → skills/setup/assets/conflict-catalog.json

Also updates every cross-reference across:
  skills/**/*.md, hooks/scripts/*.sh, scripts/*, .claude-plugin/*, CLAUDE.md, README.md, CHANGELOG.md (live entries only)

Skips: docs/_research/ (historical), .git/, node_modules/, *.original (those move with their twins).
"""
import pathlib, re, sys, shutil

ROOT = pathlib.Path("/home/tom/development/blitz")

# Build the rename map: source → target
RENAMES = {}

# Per-skill reference.md and reference.md.original
for ref in (ROOT / "skills").glob("*/reference.md"):
    RENAMES[ref] = ref.parent / "references" / "main.md"
for orig in (ROOT / "skills").glob("*/reference.md.original"):
    RENAMES[orig] = orig.parent / "references" / "main.md.original"

# Special cases
RENAMES[ROOT / "skills/ui-audit/CHECKS.md"] = ROOT / "skills/ui-audit/references/checks.md"
RENAMES[ROOT / "skills/ui-audit/PATTERNS.md"] = ROOT / "skills/ui-audit/references/patterns.md"
RENAMES[ROOT / "skills/setup/conflict-catalog.json"] = ROOT / "skills/setup/assets/conflict-catalog.json"

# Filter: only sources that actually exist
RENAMES = {s: t for s, t in RENAMES.items() if s.exists()}
print(f"Will rename {len(RENAMES)} files.", file=sys.stderr)

# Build ref-update rules: text replacements that work BEFORE files move
# (relative refs from SKILL.md to its own reference.md become references/main.md;
# we only operate on files INSIDE the skill directory, so use a simple textual swap.)
#
# For markdown links: [text](reference.md) → [text](references/main.md)
# For markdown links with anchor: [text](reference.md#x) → [text](references/main.md#x)
# Same for CHECKS.md, PATTERNS.md, conflict-catalog.json.

# Files to scan for ref updates
SCAN_DIRS = [
    ROOT / "skills",
    ROOT / "hooks" / "scripts",
    ROOT / "scripts",
    ROOT / ".claude-plugin",
]
SCAN_FILES = [
    ROOT / "CLAUDE.md",
    ROOT / "README.md",
    ROOT / "CHANGELOG.md",
]

def find_targets():
    targets = set()
    for d in SCAN_DIRS:
        if not d.exists():
            continue
        for f in d.rglob("*"):
            if not f.is_file():
                continue
            if "node_modules" in f.parts or ".git" in f.parts:
                continue
            if f.suffix in (".md", ".sh", ".py", ".json", ".js"):
                # Don't rewrite .original backups (they document the pre-compress state)
                if f.name.endswith(".original"):
                    continue
                targets.add(f)
    for f in SCAN_FILES:
        if f.exists():
            targets.add(f)
    # Skip the historical research docs
    return [f for f in targets if "/_research/" not in str(f)]

# Substitution patterns (each is a (regex, replacement) pair)
# Order matters — match more-specific patterns first.
# Use word boundaries / explicit chars to avoid false matches inside other words.
RULES = [
    # reference.md.original → references/main.md.original
    (re.compile(r'(?<![\w/])reference\.md\.original\b'), 'references/main.md.original'),
    # reference.md → references/main.md (preserves anchors via the regex tail-anchor pass-through)
    (re.compile(r'(?<![\w/])reference\.md\b'), 'references/main.md'),
    # CHECKS.md (only meaningful inside ui-audit context, but the global swap is safe — no other CHECKS.md exists)
    (re.compile(r'(?<![\w/])CHECKS\.md\b'), 'references/checks.md'),
    (re.compile(r'(?<![\w/])PATTERNS\.md\b'), 'references/patterns.md'),
    # conflict-catalog.json (only setup uses it)
    (re.compile(r'(?<![\w/])conflict-catalog\.json\b'), 'assets/conflict-catalog.json'),
]

# Step 1 — rewrite all references BEFORE moving files
print("\n=== Step 1: Rewriting cross-references ===", file=sys.stderr)
ref_updates = 0
for f in find_targets():
    text = f.read_text(errors="replace")
    new_text = text
    file_changes = 0
    for pat, repl in RULES:
        new_text, n = pat.subn(repl, new_text)
        file_changes += n
    if new_text != text:
        f.write_text(new_text)
        ref_updates += file_changes
        print(f"  ✓ {f.relative_to(ROOT)}: {file_changes} substitutions")
print(f"\nTotal ref substitutions: {ref_updates}")

# Step 2 — move files
print("\n=== Step 2: Moving files ===", file=sys.stderr)
moved = 0
for src, tgt in sorted(RENAMES.items()):
    tgt.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(src), str(tgt))
    moved += 1
    print(f"  ✓ {src.relative_to(ROOT)} → {tgt.relative_to(ROOT)}")
print(f"\nTotal files moved: {moved}")

# Step 3 — special-case the reference-compression-validate.sh find pattern
# (its glob `reference.md.original` no longer matches anything; switch to the new path)
HOOK = ROOT / "hooks/scripts/reference-compression-validate.sh"
text = HOOK.read_text()
new_text = text.replace(
    "find skills -type f -name 'reference.md.original'",
    "find skills -type f -path '*/references/main.md.original'",
)
if new_text != text:
    HOOK.write_text(new_text)
    print(f"\n  ✓ Updated find pattern in {HOOK.relative_to(ROOT)}")
else:
    print(f"\n  (reference-compression-validate.sh already updated by step 1)", file=sys.stderr)
