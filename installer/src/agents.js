'use strict';

const fs = require('fs');
const path = require('path');
const { AGENT_NAMES, INSTALLED_PLUGINS, PLUGIN_KEY } = require('./constants');
const { ensureDir } = require('./settings');
const { success, fail, info } = require('./ui');

function findPluginCache() {
  try {
    const data = JSON.parse(fs.readFileSync(INSTALLED_PLUGINS, 'utf-8'));
    const entries = data?.plugins?.[PLUGIN_KEY] || data?.plugins?.['cc-plugin-suite@cc-plugin-suite'];
    if (entries && entries.length > 0) {
      return entries[0].installPath;
    }
  } catch { /* not installed */ }
  return null;
}

function copyAgents(projectDir, opts = {}) {
  const cachePath = findPluginCache();
  if (!cachePath) {
    fail('Cannot find plugin cache — install the plugin first');
    return false;
  }

  const agentsSource = path.join(cachePath, 'agents');
  const agentsDest = path.join(projectDir, '.claude', 'agents');

  if (!fs.existsSync(agentsSource)) {
    fail(`Agent source directory not found: ${agentsSource}`);
    return false;
  }

  if (opts.dryRun) {
    for (const name of AGENT_NAMES) {
      info(`Would copy ${name} → .claude/agents/${name} (with acceptEdits)`);
    }
    return true;
  }

  ensureDir(agentsDest);
  let copied = 0;

  for (const name of AGENT_NAMES) {
    const src = path.join(agentsSource, name);
    const dest = path.join(agentsDest, name);

    if (!fs.existsSync(src)) {
      fail(`Agent not found in cache: ${name}`);
      continue;
    }

    let content = fs.readFileSync(src, 'utf-8');
    content = injectPermissionMode(content);
    fs.writeFileSync(dest, content, 'utf-8');
    copied++;
  }

  success(`${copied} agents configured with acceptEdits mode`);
  return true;
}

function injectPermissionMode(content) {
  // Find the end of frontmatter (second ---) and insert permissionMode
  const lines = content.split('\n');
  if (lines[0] !== '---') return content;

  // Check if permissionMode already exists
  let inFrontmatter = false;
  let endIndex = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === '---') {
      endIndex = i;
      break;
    }
    if (lines[i].startsWith('permissionMode:')) {
      return content; // Already has it
    }
  }

  if (endIndex === -1) return content;

  // Remove the comment about permissionMode not being supported (it IS supported for project agents)
  const filtered = lines.filter((line) =>
    !line.includes('permissionMode is not supported for plugin agents')
  );

  // Recompute endIndex after filtering
  let newEndIndex = -1;
  for (let i = 1; i < filtered.length; i++) {
    if (filtered[i] === '---') {
      newEndIndex = i;
      break;
    }
  }

  if (newEndIndex === -1) return content;

  // Insert permissionMode before the closing ---
  filtered.splice(newEndIndex, 0, 'permissionMode: acceptEdits');
  return filtered.join('\n');
}

function removeAgents(projectDir, opts = {}) {
  const agentsDir = path.join(projectDir, '.claude', 'agents');
  if (!fs.existsSync(agentsDir)) {
    info('No .claude/agents/ directory (nothing to remove)');
    return false;
  }

  let removed = 0;
  for (const name of AGENT_NAMES) {
    const p = path.join(agentsDir, name);
    if (fs.existsSync(p)) {
      if (opts.dryRun) {
        info(`Would remove .claude/agents/${name}`);
      } else {
        fs.unlinkSync(p);
      }
      removed++;
    }
  }

  if (removed > 0) {
    if (!opts.dryRun) success(`Removed ${removed} blitz agents`);
  } else {
    info('No blitz agents found in .claude/agents/');
  }
  return removed > 0;
}

module.exports = { copyAgents, removeAgents };
