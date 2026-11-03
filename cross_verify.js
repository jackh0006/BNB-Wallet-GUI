#!/usr/bin/env node
'use strict';

// Cross-verification entry point. It is intentionally the same check as
// verify_ethers.js: the Dart bytes are parsed and recovered by ethers, never by
// web3dart. Keeping one implementation prevents the two paths from drifting.
console.log('BNB Wallet — cross-verification: Dart bytes → ethers.js');
require('./verification/verify.cjs');
