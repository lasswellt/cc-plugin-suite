#!/usr/bin/env python3
"""Trim the verbose ~500-char session-registration preamble across SKILL.md
files. Two layouts observed:
  (a) Inline list-item: `0. **Register session.** Follow the session protocol...`
  (b) Subsection body:  `### 0.0 Register Session\n\nFollow the session protocol...`

Both forms have the same body text ("Follow the session protocol from ... verbose-progress.md.").
Replace the body with a canonical ~270-char citation; preserve the surrounding
list-item or section-header structure.
"""
import pathlib, re, sys

ROOT = pathlib.Path("/home/tom/development/blitz/skills")

# Canonical body (no list-item / header prefix — those are preserved).
CANONICAL_BODY = (
    "Follow [session-protocol.md](/_shared/session-protocol.md) "
    "§Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). "
    "Print verbose progress at every phase transition, decision point, and skill-specific dispatch."
)

# Match ANY line(s) starting with "Follow the session protocol from [...]"
# and ending with "verbose-progress.md.". Allow the link path to be relative
# (`session-protocol.md`) or plugin-absolute (`/_shared/session-protocol.md`).
BODY_RE = re.compile(
    r'Follow the session protocol from '
    r'\[[^\]]*session-protocol\.md\]\(/_shared/session-protocol\.md\)\s+\*\*and\*\*\s+the '
    r'\[[^\]]*verbose-progress\.md\]\(/_shared/verbose-progress\.md\)\s+protocol\.[^\n]*?'
    r'verbose-progress\.md\.',
    re.S,
)

# Special case: numbered list-item form with leading "0. **Register session.** "
# is matched separately so we strip both the marker AND the body in one pass.
INLINE_RE = re.compile(
    r'^(\s*)0\.\s+\*\*Register session\.\*\*\s+'
    r'Follow the session protocol from '
    r'\[[^\]]*session-protocol\.md\]\(/_shared/session-protocol\.md\)\s+\*\*and\*\*\s+the '
    r'\[[^\]]*verbose-progress\.md\]\(/_shared/verbose-progress\.md\)\s+protocol\.[^\n]*?'
    r'verbose-progress\.md\.\s*$',
    re.M | re.S,
)

def trim_one(path):
    text = path.read_text()
    original_len = len(text)

    # First pass: numbered list-item form.
    def inline_repl(m):
        indent = m.group(1)
        return f"{indent}0. **Register session.** {CANONICAL_BODY}"
    text2, n_inline = INLINE_RE.subn(inline_repl, text)

    # Second pass: bare body form (already-numbered items skipped because the
    # inline regex consumed them above; what remains is bare bodies under a
    # section header).
    text3, n_bare = BODY_RE.subn(CANONICAL_BODY, text2)

    if text3 == text:
        return None
    path.write_text(text3)
    return original_len - len(text3), n_inline, n_bare

total_saved = 0
trimmed = 0
for f in sorted(ROOT.glob("*/SKILL.md")):
    result = trim_one(f)
    if result is None:
        continue
    saved, n_inline, n_bare = result
    trimmed += 1
    total_saved += saved
    print(f"  ✓ {f.parent.name}: -{saved} chars (inline={n_inline}, bare={n_bare})")
print(f"\nTrimmed {trimmed} SKILL.md preambles, saved {total_saved} chars total.")
