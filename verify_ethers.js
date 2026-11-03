#!/usr/bin/env node
'use strict';

// Backwards-compatible entry point. The real independent check lives in
// verification/verify.cjs and imports only ethers.js.
console.log('BNB Wallet — independent ethers.js cold-signing verification');
require('./verification/verify.cjs');
