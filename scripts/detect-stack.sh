#!/usr/bin/env bash
set -uo pipefail
# Detect project tech stack for adaptive skill behavior
# Output is injected into skill context via !`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

echo "## Detected Stack Profile"

# Framework
if [ -f "nuxt.config.ts" ] || [ -f "nuxt.config.js" ]; then
  echo "- **Framework**: Nuxt 3"
elif [ -f "vite.config.ts" ] || [ -f "vue.config.js" ]; then
  echo "- **Framework**: Vue 3 (Vite)"
else
  echo "- **Framework**: Unknown"
fi

# UI Framework (from package.json)
if [ -f "package.json" ]; then
  if grep -q '"tailwindcss"' package.json 2>/dev/null; then
    echo "- **UI Framework**: Tailwind CSS"
  elif grep -q '"quasar"' package.json 2>/dev/null; then
    echo "- **UI Framework**: Quasar"
  elif grep -q '"vuetify"' package.json 2>/dev/null; then
    echo "- **UI Framework**: Vuetify"
  else
    echo "- **UI Framework**: None detected"
  fi
fi

# Firebase
if [ -f "firebase.json" ]; then
  echo "- **Backend**: Firebase/GCP"
  if [ -d "functions" ] || [ -d "backend/functions" ]; then
    echo "- **Cloud Functions**: Yes"
  fi
fi

# Monorepo / Build
if [ -f "nx.json" ]; then
  echo "- **Build System**: Nx monorepo"
elif [ -f "pnpm-workspace.yaml" ]; then
  echo "- **Build System**: pnpm workspaces"
elif [ -f "turbo.json" ]; then
  echo "- **Build System**: Turborepo"
else
  echo "- **Build System**: Single package"
fi

# Package manager
if [ -f "pnpm-lock.yaml" ]; then echo "- **Package Manager**: pnpm"
elif [ -f "yarn.lock" ]; then echo "- **Package Manager**: yarn"
elif [ -f "package-lock.json" ]; then echo "- **Package Manager**: npm"
fi

# Validation, testing, state
if [ -f "package.json" ]; then
  grep -q '"zod"' package.json 2>/dev/null && echo "- **Validation**: Zod"
  grep -q '"vitest"' package.json 2>/dev/null && echo "- **Testing**: Vitest"
  grep -q '"jest"' package.json 2>/dev/null && echo "- **Testing**: Jest"
  grep -q '"pinia"' package.json 2>/dev/null && echo "- **State**: Pinia"
  grep -q '"vuefire"' package.json 2>/dev/null && echo "- **Firestore Binding**: VueFire"
  grep -q '"xstate"' package.json 2>/dev/null && echo "- **State Machines**: XState"
fi

# Authorization
if [ -f "package.json" ]; then
  grep -q '"@openfga"' package.json 2>/dev/null && echo "- **Authorization**: OpenFGA"
fi
