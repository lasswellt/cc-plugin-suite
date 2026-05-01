# Frontend Design Heuristics (paraphrased)

Paraphrase of the Anthropic `frontend-design:frontend-design` skill's design philosophy. Used by `ui-build` Phase 3.0 (when `frontend-design` is not invoked) and `agents/design-critic.md`.

**Why a paraphrase**: `frontend-design`'s SKILL.md ships under a non-standard `LICENSE.txt` of unknown redistribution terms. Bundling its prose verbatim in blitz risks a license violation. This file restates the philosophy in our own words. The structure and the banned-list specifics are factual recordings of what the skill enforces; the language is original.

**Authoritative source** (read it directly when in doubt): https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md

---

## 1. Core principle

> Choose a clear conceptual direction and execute it with precision. Bold maximalism and refined minimalism both work — the key is intentionality, not intensity.

The single failure mode this principle fights is **generic AI output**: designs that could come from any model on any day. Anything that looks like everything else has zero creative distinction.

## 2. Aesthetic-decision phase (precedes any code)

Pick exactly one tone. Do not blend. Commit:

| Tone | Sketch |
|---|---|
| brutalist/minimal | Visible structural elements, raw type, exposed grids |
| maximalist | Layered information density, multiple type weights, busy-on-purpose |
| retro-futuristic | 80s/90s computing motifs, scanlines, monospace, gradient skies |
| organic/natural | Earth palette, irregular shapes, hand-drawn elements |
| luxury/refined | Generous whitespace, restrained palette, premium typography |
| playful/toy-like | Bright color, rounded corners on purpose, illustrative |
| editorial/magazine | Strong typographic hierarchy, image-led, asymmetric layouts |
| art-deco | Geometric ornament, gold/black, stepped forms |
| soft/pastel | Low-contrast, gentle color, delicate type |
| industrial | Mechanical type, gridded, monochrome |
| dark/moody | Black/charcoal base, single saturated accent, low light |
| lo-fi/zine | Photocopy textures, hand-cut composition, raw |
| handcrafted/artisanal | Imperfect lines, mixed materials, signatures of human work |

A landing page that mixes "luxury" and "playful" reads as confused, not eclectic. Pick one.

## 3. Typography

- **Distinctive display + refined body pair.** Both fonts must have character. A geometric sans alone is not a pair.
- **Banned as primary**: Inter, Roboto, Arial, system fonts (without an explicit fallback chain), Space Grotesk.
  - These are not bad fonts. They are *overused* fonts. Using them by default is the single most reliable signal of generic AI output.
- **Pair examples** (illustrative, not prescriptive):
  - Editorial: Playfair Display + Source Serif
  - Brutalist: Space Mono + Inter Tight (ironic use OK; default use is banned)
  - Luxury: Bodoni Moda + Lora
  - Playful: Fraunces + Quicksand
  - Industrial: IBM Plex Mono + IBM Plex Sans
  - Lo-fi/zine: Special Elite + Courier Prime
- **Hierarchy must form a scale.** 4–6 sizes related by ratio (1.25 / 1.333 / golden / etc.), not arbitrary.

## 4. Color

- **Dominant + accent beats evenly-distributed.** A 60-30-10 distribution (dominant / secondary / accent) reads as intentional. Equal-weight palettes read as confused.
- **One accent unless multi-color is required.** A status indicator system needs multiple colors; a marketing page does not.
- **CSS variables for everything.** Hardcoded `#FFAA00` is a smell. Use `var(--color-accent)` even for one-off uses.
- **Banned by name**: purple gradients on white background. This combination has been done so much it now signals "AI made this" the way clip art used to signal "made in PowerPoint."

## 5. Motion

- **One orchestrated reveal beats scattered micro-interactions.** A staggered animation-delay sequence on page load creates a sense of intentional choreography. Twelve hover-bounce micro-interactions create visual noise.
- **Pick a vocabulary**: `staggered reveals on enter`, `parallax depth on scroll`, `micro-interactions on hover`, OR `none/static`. Don't mix three.
- **`prefers-reduced-motion: reduce` is mandatory** if any motion is present. This is an accessibility floor, not a nice-to-have.

## 6. Composition

- **Asymmetry > centered-everything.** Centered hero + centered subhead + centered CTA reads as a default template. Off-center hero with intentional whitespace reads as designed.
- **Diagonal flow, overlap, full-bleed, dramatic scale jumps** are tools, not decorations. Use them when they serve the tone.
- **Generous whitespace OR controlled density.** Pick one and commit. A page with both feels indecisive.
- **Visual atmosphere**: noise textures, grain overlays, subtle gradients, glassmorphism, parallax depth — these add identity. Use sparingly; one signature texture beats five.

## 7. The NEVER list (auto-fail signals)

These produce auto-fail in the design-critic agent's Creative Distinction dimension:

1. Inter / Roboto / Arial / Space Grotesk as primary font
2. Purple gradient on white background
3. All-rounded corners (every box `rounded-lg`, every button `rounded-full`)
4. All-centered layouts (hero, subhero, CTA stack centered with no offset)
5. Default Tailwind palette out of the box (`bg-blue-500 text-white`)
6. Shadcn / Material defaults on top of generic gray, untouched
7. Cookie-cutter feature grid (3-column, equal cards, icon + heading + body)
8. Same design recognizable across 3+ unrelated outputs

If a screenshot ticks more than 2 of these, design-critic emits REWORK regardless of other dimensions.

## 8. Dense info display (when "generous whitespace" doesn't fit)

For dashboards, tables, admin UI, and other information-dense pages, "controlled density" is the correct mode. The mistake is to default to whitespace-heavy marketing layouts for productivity tools.

Density done well:
- Type sizes compressed into a 12px–14px–16px–20px scale (not 16/20/24/32)
- Single-pixel borders for separators, not generous padding
- Color used to encode meaning (status, priority), not decoration
- Information hierarchy via type weight + position, not card-on-card-on-card
- Vertical rhythm at 4px/8px grid, not 8px/16px

Bloomberg Terminal, Linear, Notion's database views, Airtable: density done well. Generic admin starter templates: density failed.

## 9. Acceptance signals (what success looks like)

A successful design-critic PASS has:
- All 5 dimensions ≥7
- Specifically Creative Distinction ≥7 (the hardest)
- Tone identifiable from a 1-second glance at any single screenshot
- Typography pair recognizable as a pair
- Single dominant + accent palette
- Motion present or absent on purpose, with `prefers-reduced-motion` honored
- Composition off-template (some asymmetry, intentional weight distribution)

If any of those are missing, the result is competent-but-generic. That's a 5–6, not a 7.

---

## Related

- `agents/design-critic.md` — primary consumer
- `skills/ui-build/SKILL.md` Phase 3.0 + 5.4.2 — invocation site
- `skills/design-extract/SKILL.md` — emits DESIGN.md from existing codebase tokens
- `docs/_research/2026-05-01_autonomous-blitz-quality-efficiency.md` §3.4 — research basis
- Authoritative external: https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md
