# Package Install Policy

Canonical rule for how skills and agents add new npm/pnpm packages. Single source of truth — every skill that runs `pnpm add` / `npm install` / `yarn add` / `bun add` MUST link here from its body.

## The rule

**When adding a NEW package, always resolve to the latest registry version. Never invent a version number from training-data memory.**

LLM training data is months stale. A model that remembers `vue@3.4.21` will silently introduce a 9-month-old version when `vue@3.5.x` is current. This is one of the highest-frequency drift sources in agent-authored code.

## Three states, one rule each

### 1. Net-new dependency, no user-specified version

Run the install command **without a version pin**. The package manager resolves to the registry's `latest` tag and writes the appropriate caret-range to `package.json`.

```bash
# pnpm (preferred — fast, strict, deterministic lockfile)
pnpm add <package>                  # runtime dep
pnpm add -D <package>               # dev dep
pnpm add -E <package>               # exact version, no caret (use for tooling that demands lockstep)

# npm
npm install <package>               # runtime
npm install --save-dev <package>    # dev
npm install --save-exact <package>  # exact

# yarn / bun
yarn add <package>          /  bun add <package>
yarn add -D <package>       /  bun add -d <package>
```

**Do NOT write `pnpm add <package>@latest`** — it's redundant (bare add already resolves `latest`) and the literal `@latest` confuses some monorepo tooling.

### 2. User explicitly specified a version

```
user: "install vue-router@4.4.5"
```

Use exactly what they said: `pnpm add vue-router@4.4.5`. Do not "upgrade" silently. The user's intent is authoritative.

### 3. Compatibility-pinned dependency (peer constraint, framework lockstep, etc.)

When the package MUST match a peer constraint (e.g., a Vite plugin must match the project's Vite major), resolve via:

```bash
# Inspect what the project actually uses, then pin to that major
PEER_VERSION=$(node -p "require('./package.json').dependencies['vite']")
pnpm add @vitejs/plugin-vue@^${PEER_VERSION}
```

Document the constraint in the commit message: `chore: add @vitejs/plugin-vue@^7.x.y (peer of vite@^7.x)`. Do not pin to the latest if it breaks peer compatibility.

## Verification step (mandatory before commit)

After `pnpm add` / `npm install`, verify the resolved version against the registry to confirm the install actually got the latest:

```bash
# Single-source check (works for npm + pnpm + yarn + bun)
PKG=<package>
LATEST=$(npm view "$PKG" version)                    # registry truth
INSTALLED=$(node -p "require('./package.json').dependencies['$PKG'] || require('./package.json').devDependencies['$PKG']" 2>/dev/null | tr -d '^~')
echo "registry: $LATEST  /  installed: $INSTALLED"

# If they differ by major or minor, abort and investigate.
# If they differ by patch only, that's acceptable (caret range, lockfile may stay).
```

If the install resolved to an older version, the package likely has a peer constraint that the registry-latest violates — case 3 above. Surface this in the dispatch summary so the user can review.

## Anti-patterns (block on review)

- `pnpm add foo@1.2.3` where `1.2.3` was invented from memory rather than checked.
- `pnpm add foo@^1.0.0` to "be safe" — the package manager already writes a caret; explicit caret-zero pins lock in oldest-1.x.
- Editing `package.json` directly to add a version string without running the install. The lockfile and `node_modules` will be out of sync.
- Copying a `package.json` snippet from a stale tutorial / Stack Overflow answer / blog post. Always rerun the install command instead.
- Adding `"foo": "*"` or `"foo": "latest"` as the version range — `*` and literal `latest` in a manifest cause non-reproducible builds. Use the caret range that `pnpm add` writes by default.

## Tooling integrations

- **`/blitz:dep-health`** — periodic audit (CVE + outdated). Runs `npm outdated` / `pnpm outdated` against the registry; flags any dep behind by ≥1 minor.
- **`/blitz:migrate <package>`** — when intentionally upgrading. Researches breaking changes, applies migration in atomic steps, verifies after each.
- **PreToolUse hook (future)** — `block-stale-package-add.sh` could intercept Bash commands of the form `pnpm add foo@<version>` and reject the call if `<version>` is more than 1 major behind the registry latest. Not yet implemented; planned for v1.12.

## Source-of-truth file

This document. If your skill says "always use latest version," it must link here for the operational details. Don't duplicate the rule — it will drift.
