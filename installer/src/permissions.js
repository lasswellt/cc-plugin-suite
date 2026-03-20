'use strict';

const { BASE_PERMISSIONS, STACK_PERMISSIONS } = require('./constants');

function generatePermissions(stack) {
  const allow = [...BASE_PERMISSIONS.allow];
  const deny = [...BASE_PERMISSIONS.deny];

  // Package manager
  if (stack.packageManager && STACK_PERMISSIONS[stack.packageManager]) {
    allow.push(...STACK_PERMISSIONS[stack.packageManager].allow);
    deny.push(...STACK_PERMISSIONS[stack.packageManager].deny);
  }

  // Firebase
  if (stack.backend === 'firebase') {
    allow.push(...STACK_PERMISSIONS.firebase.allow);
  }

  // Framework
  if (stack.framework === 'vue' || stack.framework === 'nuxt') {
    allow.push(...STACK_PERMISSIONS.vue.allow);
  }

  // VueFire
  if (stack.vuefire) {
    allow.push(...STACK_PERMISSIONS.vuefire.allow);
  }

  // UI Framework
  if (stack.uiFramework && STACK_PERMISSIONS[stack.uiFramework]) {
    allow.push(...STACK_PERMISSIONS[stack.uiFramework].allow);
  }

  return { allow: dedupe(allow), deny: dedupe(deny) };
}

function dedupe(arr) {
  return [...new Set(arr)];
}

module.exports = { generatePermissions };
