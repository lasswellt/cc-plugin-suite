'use strict';

const fs = require('fs');
const path = require('path');

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function read(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    return JSON.parse(content);
  } catch {
    return {};
  }
}

function write(filePath, data) {
  ensureDir(path.dirname(filePath));

  // Create backup if file exists
  if (fs.existsSync(filePath)) {
    fs.copyFileSync(filePath, filePath + '.bak');
  }

  // Preserve $schema at the top by ensuring key order
  const ordered = {};
  if (data.$schema) ordered.$schema = data.$schema;
  Object.assign(ordered, data);

  fs.writeFileSync(filePath, JSON.stringify(ordered, null, 2) + '\n', 'utf-8');
}

function deepMerge(target, source) {
  const result = { ...target };
  for (const key of Object.keys(source)) {
    if (
      source[key] && typeof source[key] === 'object' && !Array.isArray(source[key]) &&
      result[key] && typeof result[key] === 'object' && !Array.isArray(result[key])
    ) {
      result[key] = deepMerge(result[key], source[key]);
    } else {
      result[key] = source[key];
    }
  }
  return result;
}

function unionArray(existing, additions) {
  const set = new Set(existing);
  const result = [...existing];
  for (const item of additions) {
    if (!set.has(item)) {
      result.push(item);
      set.add(item);
    }
  }
  return result;
}

function removeFromArray(existing, removals) {
  const removeSet = new Set(removals);
  return existing.filter((item) => !removeSet.has(item));
}

function mergePermissions(settings, permissions) {
  if (!settings.permissions) settings.permissions = {};
  if (!settings.permissions.allow) settings.permissions.allow = [];
  if (!settings.permissions.deny) settings.permissions.deny = [];

  settings.permissions.allow = unionArray(settings.permissions.allow, permissions.allow || []);
  settings.permissions.deny = unionArray(settings.permissions.deny, permissions.deny || []);

  return settings;
}

function setNestedValue(obj, keyPath, value) {
  const keys = keyPath.split('.');
  let current = obj;
  for (let i = 0; i < keys.length - 1; i++) {
    if (!current[keys[i]] || typeof current[keys[i]] !== 'object') {
      current[keys[i]] = {};
    }
    current = current[keys[i]];
  }
  current[keys[keys.length - 1]] = value;
  return obj;
}

function getNestedValue(obj, keyPath) {
  const keys = keyPath.split('.');
  let current = obj;
  for (const key of keys) {
    if (!current || typeof current !== 'object') return undefined;
    current = current[key];
  }
  return current;
}

function removeNestedKey(obj, keyPath) {
  const keys = keyPath.split('.');
  let current = obj;
  for (let i = 0; i < keys.length - 1; i++) {
    if (!current || typeof current !== 'object') return obj;
    current = current[keys[i]];
  }
  if (current && typeof current === 'object') {
    delete current[keys[keys.length - 1]];
  }
  return obj;
}

module.exports = {
  ensureDir,
  read,
  write,
  deepMerge,
  unionArray,
  removeFromArray,
  mergePermissions,
  setNestedValue,
  getNestedValue,
  removeNestedKey,
};
