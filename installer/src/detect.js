'use strict';

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

function which(cmd) {
  try {
    return execSync(`which ${cmd} 2>/dev/null`, { encoding: 'utf-8' }).trim();
  } catch {
    return null;
  }
}

function getVersion(cmd) {
  try {
    const output = execSync(`${cmd} --version 2>&1`, { encoding: 'utf-8' }).trim();
    const match = output.match(/(\d+\.\d+[\.\d]*)/);
    return match ? match[1] : output.split('\n')[0];
  } catch {
    return null;
  }
}

function detectClaude() {
  // Check common locations
  const candidates = [
    which('claude'),
    path.join(os.homedir(), '.local', 'bin', 'claude'),
    '/usr/local/bin/claude',
    path.join(os.homedir(), '.claude', 'bin', 'claude'),
  ].filter(Boolean);

  for (const p of candidates) {
    if (fs.existsSync(p)) {
      return { path: p, version: getVersion(p) };
    }
  }
  return null;
}

function isWSL() {
  try {
    const release = os.release().toLowerCase();
    return release.includes('microsoft') || release.includes('wsl');
  } catch {
    return false;
  }
}

function detectExistingInstall() {
  const { INSTALLED_PLUGINS, KNOWN_MARKETPLACES, MARKETPLACE_NAME, PLUGIN_KEY } = require('./constants');

  let marketplaceRegistered = false;
  let pluginInstalled = false;
  let installedVersion = null;

  try {
    const marketplaces = JSON.parse(fs.readFileSync(KNOWN_MARKETPLACES, 'utf-8'));
    marketplaceRegistered = MARKETPLACE_NAME in (marketplaces || {});
  } catch { /* not installed */ }

  try {
    const plugins = JSON.parse(fs.readFileSync(INSTALLED_PLUGINS, 'utf-8'));
    const entries = plugins?.plugins?.[PLUGIN_KEY];
    if (entries && entries.length > 0) {
      pluginInstalled = true;
      installedVersion = entries[0].version;
    }
    // Also check old name
    if (!pluginInstalled) {
      const oldEntries = plugins?.plugins?.['cc-plugin-suite@cc-plugin-suite'];
      if (oldEntries && oldEntries.length > 0) {
        pluginInstalled = true;
        installedVersion = oldEntries[0].version;
      }
    }
  } catch { /* not installed */ }

  return { marketplaceRegistered, pluginInstalled, installedVersion };
}

function detectEnvironment() {
  const claude = detectClaude();
  const nodePath = which('node');
  const python3Path = which('python3');
  const bashPath = which('bash');
  const gitPath = which('git');
  const jqPath = which('jq');

  return {
    claude,
    node:    { path: nodePath,    version: nodePath ? getVersion('node') : null },
    python3: { path: python3Path, version: python3Path ? getVersion('python3') : null },
    bash:    { path: bashPath,    version: bashPath ? getVersion('bash') : null },
    git:     { path: gitPath,     version: gitPath ? getVersion('git') : null },
    jq:      { path: jqPath,      version: jqPath ? getVersion('jq') : null },
    platform: process.platform,
    wsl: isWSL(),
    existing: detectExistingInstall(),
  };
}

module.exports = { detectEnvironment };
