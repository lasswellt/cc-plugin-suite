#!/usr/bin/env node

'use strict';

const { run } = require('../src/index');

run(process.argv).catch((err) => {
  console.error(`\n  Error: ${err.message}`);
  if (process.env.DEBUG) console.error(err.stack);
  process.exit(1);
});
