'use strict';

const readline = require('readline');
const { VERSION } = require('./constants');

const isColorSupported = process.stdout.isTTY && !process.env.NO_COLOR;

const c = (code) => isColorSupported ? `\x1b[${code}m` : '';

const color = {
  reset:   c('0'),
  bold:    c('1'),
  dim:     c('2'),
  red:     c('31'),
  green:   c('32'),
  yellow:  c('33'),
  blue:    c('34'),
  magenta: c('35'),
  cyan:    c('36'),
  white:   c('37'),
};

const sym = {
  check:  isColorSupported ? '✓' : '[ok]',
  cross:  isColorSupported ? '✖' : '[fail]',
  warn:   isColorSupported ? '⚠' : '[warn]',
  bolt:   isColorSupported ? '⚡' : '*',
  arrow:  isColorSupported ? '→' : '->',
  branch: isColorSupported ? '├─' : '|--',
  corner: isColorSupported ? '└─' : '`--',
  pipe:   isColorSupported ? '│ ' : '|  ',
};

function banner() {
  const byel = c('93');  // bright yellow
  const bcyn = c('96');  // bright cyan
  const bwht = c('97');  // bright white

  const lines = [
    '',
    `${byel}${color.bold}   ─── ${sym.bolt} ──────────────────────────────────${color.reset}`,
    '',
    `${byel}${color.bold}   ██████╗ ██╗     ██╗████████╗███████╗${color.reset}`,
    `${color.yellow}   ██╔══██╗██║     ██║╚══██╔══╝╚══███╔╝${color.reset}`,
    `${bwht}${color.bold}   ██████╔╝██║     ██║   ██║     ███╔╝ ${color.reset}`,
    `${bcyn}   ██╔══██╗██║     ██║   ██║    ███╔╝  ${color.reset}`,
    `${color.cyan}   ██████╔╝███████╗██║   ██║   ███████╗${color.reset}`,
    `${color.dim}   ╚═════╝ ╚══════╝╚═╝   ╚═╝   ╚══════╝${color.reset}`,
    '',
    `${color.cyan}   ──────────────────────────────── ${sym.bolt} ───${color.reset}`,
    '',
    `${color.dim}     Claude Code Plugin Installer · v${VERSION}${color.reset}`,
    `${color.dim}       31 skills · 6 agents · 9 hooks${color.reset}`,
    '',
  ];
  console.log(lines.join('\n'));
}

function success(message) {
  console.log(`    ${color.green}${sym.check}${color.reset} ${message}`);
}

function fail(message) {
  console.log(`    ${color.red}${sym.cross}${color.reset} ${message}`);
}

function warn(message) {
  console.log(`    ${color.yellow}${sym.warn}${color.reset} ${message}`);
}

function info(message) {
  console.log(`    ${color.dim}${message}${color.reset}`);
}

function header(message) {
  console.log(`\n  ${color.bold}${message}${color.reset}`);
}

function tree(items) {
  for (let i = 0; i < items.length; i++) {
    const prefix = i === items.length - 1 ? sym.corner : sym.branch;
    console.log(`    ${prefix} ${items[i]}`);
  }
}

function treeItem(label, value, ok) {
  if (ok === true) return `${label} ${color.green}${sym.check}${color.reset} ${color.dim}(${value})${color.reset}`;
  if (ok === false) return `${label} ${color.red}${sym.cross}${color.reset}`;
  return `${label}: ${color.cyan}${value}${color.reset}`;
}

function successBox(lines) {
  const width = 52;
  const border = `${color.green}║${color.reset}`;
  console.log('');
  console.log(`  ${color.green}╔${'═'.repeat(width)}╗${color.reset}`);
  console.log(`  ${border}${' '.repeat(width)}${border}`);
  for (const line of lines) {
    const stripped = line.replace(/\x1b\[[0-9;]*m/g, '');
    const pad = width - stripped.length;
    console.log(`  ${border}${line}${' '.repeat(Math.max(0, pad))}${border}`);
  }
  console.log(`  ${border}${' '.repeat(width)}${border}`);
  console.log(`  ${color.green}╚${'═'.repeat(width)}╝${color.reset}`);
  console.log('');
}

function permissionDiff(existing, adding) {
  const existingSet = new Set(existing);
  for (const perm of adding) {
    if (existingSet.has(perm)) {
      console.log(`      ${color.dim}${perm}${color.reset}  ${color.dim}(exists)${color.reset}`);
    } else {
      console.log(`    ${color.green}+${color.reset} ${perm}`);
    }
  }
}

const SPINNER_FRAMES = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

function createSpinner(message) {
  if (!isColorSupported) {
    process.stdout.write(`    ... ${message}\n`);
    return { stop: (ok) => { if (!ok) console.log(`    FAILED: ${message}`); } };
  }
  let i = 0;
  const id = setInterval(() => {
    const frame = SPINNER_FRAMES[i % SPINNER_FRAMES.length];
    process.stdout.write(`\r    ${color.cyan}${frame}${color.reset} ${message}`);
    i++;
  }, 80);

  return {
    stop(ok = true) {
      clearInterval(id);
      const icon = ok ? `${color.green}${sym.check}${color.reset}` : `${color.red}${sym.cross}${color.reset}`;
      process.stdout.write(`\r    ${icon} ${message}\n`);
    },
  };
}

async function prompt(question, defaultYes = true) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const hint = defaultYes ? 'Y/n' : 'y/N';
  return new Promise((resolve) => {
    rl.question(`\n  ${color.cyan}?${color.reset} ${question} (${hint}) `, (answer) => {
      rl.close();
      const a = answer.trim().toLowerCase();
      if (a === '') resolve(defaultYes);
      else resolve(a === 'y' || a === 'yes');
    });
  });
}

async function promptPath(question, defaultPath) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(`\n  ${color.cyan}?${color.reset} ${question} (${defaultPath}): `, (answer) => {
      rl.close();
      resolve(answer.trim() || defaultPath);
    });
  });
}

module.exports = {
  color,
  sym,
  banner,
  success,
  fail,
  warn,
  info,
  header,
  tree,
  treeItem,
  successBox,
  permissionDiff,
  createSpinner,
  prompt,
  promptPath,
};
