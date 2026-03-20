'use strict';

const fs = require('fs');
const path = require('path');

function detectStack(projectDir) {
  const stack = {};

  // Framework
  if (fileExists(projectDir, 'nuxt.config.ts') || fileExists(projectDir, 'nuxt.config.js')) {
    stack.framework = 'nuxt';
  } else if (fileExists(projectDir, 'vite.config.ts') || fileExists(projectDir, 'vue.config.js')) {
    stack.framework = 'vue';
  }

  // Read root and workspace package.jsons
  const deps = collectDeps(projectDir);

  // UI Framework
  if (deps.has('tailwindcss'))  stack.uiFramework = 'tailwind';
  else if (deps.has('quasar')) stack.uiFramework = 'quasar';
  else if (deps.has('vuetify')) stack.uiFramework = 'vuetify';

  // Backend
  if (fileExists(projectDir, 'firebase.json')) {
    stack.backend = 'firebase';
    if (dirExists(projectDir, 'functions') || dirExists(projectDir, 'backend/functions')) {
      stack.cloudFunctions = true;
    }
  }

  // Build system
  if (fileExists(projectDir, 'nx.json'))              stack.buildSystem = 'nx';
  else if (fileExists(projectDir, 'pnpm-workspace.yaml')) stack.buildSystem = 'pnpm-workspaces';
  else if (fileExists(projectDir, 'turbo.json'))      stack.buildSystem = 'turborepo';
  else                                                 stack.buildSystem = 'single';

  // Package manager
  if (fileExists(projectDir, 'pnpm-lock.yaml'))       stack.packageManager = 'pnpm';
  else if (fileExists(projectDir, 'yarn.lock'))        stack.packageManager = 'yarn';
  else if (fileExists(projectDir, 'package-lock.json')) stack.packageManager = 'npm';

  // Libraries
  if (deps.has('zod'))      stack.validation = 'zod';
  if (deps.has('vitest'))   stack.testing = 'vitest';
  else if (deps.has('jest')) stack.testing = 'jest';
  if (deps.has('pinia'))    stack.state = 'pinia';
  if (deps.has('vuefire'))  stack.vuefire = true;
  if (deps.has('xstate'))   stack.xstate = true;
  if (deps.has('@openfga/sdk')) stack.auth = 'openfga';

  return stack;
}

function fileExists(dir, file) {
  return fs.existsSync(path.join(dir, file));
}

function dirExists(dir, sub) {
  try {
    return fs.statSync(path.join(dir, sub)).isDirectory();
  } catch {
    return false;
  }
}

function collectDeps(projectDir) {
  const deps = new Set();
  const pkgPaths = [path.join(projectDir, 'package.json')];

  // Check workspace packages
  try {
    const rootPkg = JSON.parse(fs.readFileSync(pkgPaths[0], 'utf-8'));
    if (rootPkg.workspaces) {
      const patterns = Array.isArray(rootPkg.workspaces)
        ? rootPkg.workspaces
        : rootPkg.workspaces.packages || [];
      for (const pattern of patterns) {
        const base = pattern.replace(/\/\*$/, '');
        const dir = path.join(projectDir, base);
        try {
          for (const entry of fs.readdirSync(dir)) {
            const pkg = path.join(dir, entry, 'package.json');
            if (fs.existsSync(pkg)) pkgPaths.push(pkg);
          }
        } catch { /* skip */ }
      }
    }
  } catch { /* no root package.json */ }

  // Also check pnpm workspaces
  try {
    const wsFile = path.join(projectDir, 'pnpm-workspace.yaml');
    if (fs.existsSync(wsFile)) {
      const content = fs.readFileSync(wsFile, 'utf-8');
      const matches = content.match(/- ['"]?([^'":\n]+)/g) || [];
      for (const m of matches) {
        const pattern = m.replace(/^- ['"]?/, '').replace(/['"]$/, '').replace(/\/\*$/, '');
        const dir = path.join(projectDir, pattern);
        try {
          for (const entry of fs.readdirSync(dir)) {
            const pkg = path.join(dir, entry, 'package.json');
            if (fs.existsSync(pkg)) pkgPaths.push(pkg);
          }
        } catch { /* skip */ }
      }
    }
  } catch { /* skip */ }

  for (const pkgPath of pkgPaths) {
    try {
      const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8'));
      for (const section of ['dependencies', 'devDependencies', 'peerDependencies']) {
        if (pkg[section]) {
          for (const dep of Object.keys(pkg[section])) {
            deps.add(dep);
          }
        }
      }
    } catch { /* skip */ }
  }

  return deps;
}

function formatStack(stack) {
  const items = [];
  if (stack.framework === 'nuxt')  items.push('Framework: Nuxt 3');
  else if (stack.framework === 'vue') items.push('Framework: Vue 3 (Vite)');
  else items.push('Framework: Unknown');

  if (stack.uiFramework === 'tailwind') items.push('UI Framework: Tailwind CSS');
  else if (stack.uiFramework === 'quasar') items.push('UI Framework: Quasar');
  else if (stack.uiFramework === 'vuetify') items.push('UI Framework: Vuetify');

  if (stack.backend === 'firebase') {
    items.push('Backend: Firebase/GCP');
    if (stack.cloudFunctions) items.push('Cloud Functions: Yes');
  }

  if (stack.packageManager) items.push(`Package Manager: ${stack.packageManager}`);
  if (stack.buildSystem && stack.buildSystem !== 'single') items.push(`Build System: ${stack.buildSystem}`);
  if (stack.testing) items.push(`Testing: ${stack.testing}`);
  if (stack.state) items.push(`State: ${stack.state}`);
  if (stack.vuefire) items.push('Firestore Binding: VueFire');
  if (stack.validation) items.push(`Validation: ${stack.validation}`);

  return items;
}

module.exports = { detectStack, formatStack };
