'use strict';

const { execSync } = require('child_process');
const path = require('path');
const { PLUGIN_NAME, MARKETPLACE_NAME, PLUGIN_KEY } = require('./constants');
const { read, write, setNestedValue, getNestedValue } = require('./settings');
const { success, fail, info, createSpinner } = require('./ui');

function installPlugin(claudePath, opts = {}) {
  const cmd = `${claudePath} plugin install ${PLUGIN_NAME}@${MARKETPLACE_NAME}`;

  if (opts.dryRun) {
    info(`Would run: ${cmd}`);
    return true;
  }

  const spinner = createSpinner(`Installing plugin ${PLUGIN_NAME}@${MARKETPLACE_NAME}`);
  try {
    execSync(cmd, { stdio: 'pipe', timeout: 120000 });
    spinner.stop(true);
    return true;
  } catch (err) {
    spinner.stop(false);
    const stderr = err.stderr ? err.stderr.toString() : '';
    if (stderr.includes('already installed') || stderr.includes('Already installed')) {
      success('Plugin already installed');
      return true;
    }
    fail(`Plugin installation failed: ${stderr || err.message}`);
    info(`Manual install: ${cmd}`);
    return false;
  }
}

function enablePlugin(projectDir, opts = {}) {
  const settingsPath = path.join(projectDir, '.claude', 'settings.json');
  const settings = read(settingsPath);

  // Ensure $schema is present
  if (!settings.$schema) {
    settings.$schema = 'https://json.schemastore.org/claude-code-settings.json';
  }

  const existing = getNestedValue(settings, `enabledPlugins.${PLUGIN_KEY}`);
  if (existing === true) {
    success('Plugin already enabled for this project (skipped)');
    return false;
  }

  setNestedValue(settings, `enabledPlugins.${PLUGIN_KEY}`, true);

  // Also check for old plugin name and keep it if present
  const oldKey = 'cc-plugin-suite@cc-plugin-suite';
  const oldEnabled = getNestedValue(settings, `enabledPlugins.${oldKey}`);
  if (oldEnabled === true) {
    info('Note: old plugin name "cc-plugin-suite" also enabled — keeping both for compatibility');
  }

  if (opts.dryRun) {
    info(`Would enable "${PLUGIN_KEY}" in ${settingsPath}`);
    return true;
  }

  write(settingsPath, settings);
  success(`Plugin enabled for this project`);
  return true;
}

function disablePlugin(projectDir, opts = {}) {
  const settingsPath = path.join(projectDir, '.claude', 'settings.json');
  const settings = read(settingsPath);
  const { removeNestedKey } = require('./settings');

  let changed = false;

  if (getNestedValue(settings, `enabledPlugins.${PLUGIN_KEY}`) !== undefined) {
    removeNestedKey(settings, `enabledPlugins.${PLUGIN_KEY}`);
    changed = true;
  }

  // Also remove old name
  const oldKey = 'cc-plugin-suite@cc-plugin-suite';
  if (getNestedValue(settings, `enabledPlugins.${oldKey}`) !== undefined) {
    removeNestedKey(settings, `enabledPlugins.${oldKey}`);
    changed = true;
  }

  if (!changed) {
    info('Plugin not enabled (nothing to remove)');
    return false;
  }

  if (opts.dryRun) {
    info(`Would disable plugin in ${settingsPath}`);
    return true;
  }

  write(settingsPath, settings);
  success('Plugin disabled');
  return true;
}

module.exports = { installPlugin, enablePlugin, disablePlugin };
