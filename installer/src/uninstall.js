'use strict';

const fs = require('fs');
const path = require('path');
const { BASE_PERMISSIONS, STACK_PERMISSIONS, PLUGIN_KEY } = require('./constants');
const { read, write, removeFromArray, getNestedValue, removeNestedKey } = require('./settings');
const { success, info, header, prompt } = require('./ui');
const { disablePlugin } = require('./plugin');
const { unregisterMarketplace } = require('./marketplace');
const { removeAgents } = require('./agents');

async function uninstall(projectDir, opts = {}) {
  header('Uninstalling Blitz');

  // 1. Disable plugin
  disablePlugin(projectDir, opts);

  // 2. Remove blitz-added permissions
  const settingsPath = path.join(projectDir, '.claude', 'settings.json');
  const settings = read(settingsPath);

  if (settings.permissions) {
    // Collect all blitz-managed permissions
    const blitzAllow = [...BASE_PERMISSIONS.allow];
    const blitzDeny = [...BASE_PERMISSIONS.deny];
    for (const sp of Object.values(STACK_PERMISSIONS)) {
      blitzAllow.push(...sp.allow);
      blitzDeny.push(...sp.deny);
    }

    const originalAllow = settings.permissions.allow?.length || 0;
    const originalDeny = settings.permissions.deny?.length || 0;

    if (settings.permissions.allow) {
      settings.permissions.allow = removeFromArray(settings.permissions.allow, blitzAllow);
    }
    if (settings.permissions.deny) {
      settings.permissions.deny = removeFromArray(settings.permissions.deny, blitzDeny);
    }

    const removedAllow = originalAllow - (settings.permissions.allow?.length || 0);
    const removedDeny = originalDeny - (settings.permissions.deny?.length || 0);

    if (removedAllow > 0 || removedDeny > 0) {
      if (opts.dryRun) {
        info(`Would remove ${removedAllow} allow and ${removedDeny} deny permissions`);
      } else {
        success(`Removed ${removedAllow} allow and ${removedDeny} deny permissions`);
      }
    }
  }

  // 3. Remove env var
  if (settings.env && settings.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS) {
    if (opts.dryRun) {
      info('Would remove CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS from env');
    } else {
      delete settings.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS;
      if (Object.keys(settings.env).length === 0) delete settings.env;
      success('Removed CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS');
    }
  }

  // Write settings
  if (!opts.dryRun) {
    write(settingsPath, settings);
  }

  // 4. Remove agents
  removeAgents(projectDir, opts);

  // 5. Remove .cc-sessions
  const sessionsDir = path.join(projectDir, '.cc-sessions');
  if (fs.existsSync(sessionsDir)) {
    let shouldRemove = opts.yes;
    if (!opts.yes && !opts.dryRun) {
      shouldRemove = await prompt('Delete .cc-sessions/ directory?', false);
    }
    if (shouldRemove) {
      if (opts.dryRun) {
        info('Would delete .cc-sessions/');
      } else {
        fs.rmSync(sessionsDir, { recursive: true, force: true });
        success('Deleted .cc-sessions/');
      }
    }
  }

  // 6. Optionally remove marketplace
  let shouldRemoveMarketplace = false;
  if (!opts.yes && !opts.dryRun) {
    shouldRemoveMarketplace = await prompt('Also remove marketplace registration (global)?', false);
  }
  if (shouldRemoveMarketplace) {
    unregisterMarketplace(opts);
  }

  success('Blitz uninstalled from this project');
}

module.exports = { uninstall };
