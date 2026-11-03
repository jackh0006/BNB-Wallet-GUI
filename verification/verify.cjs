'use strict';

// Independent verification of the Dart cold-wallet transaction codec.
//
// This file intentionally imports ONLY ethers. It does not import web3dart,
// Dart, or any wallet code. It parses the exact signed bytes, recomputes the
// EIP-1559 digest, recovers the signer with ethers' secp256k1 implementation,
// and checks every field. Any drift exits non-zero.

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  Transaction,
  keccak256,
  recoverAddress,
  getBytes,
  hexlify,
} = require('ethers');

const fixture = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'fixture.json'), 'utf8'),
);
const { request, expected } = fixture;

function assertHexEqual(actual, wanted, label) {
  assert.equal(
    String(actual).toLowerCase(),
    String(wanted).toLowerCase(),
    `${label} mismatch: got ${actual}, wanted ${wanted}`,
  );
}

function assertBigEqual(actual, wanted, label) {
  assert.equal(BigInt(actual), BigInt(wanted), `${label} mismatch`);
}

function unsignedDigest(overrides = {}) {
  const tx = Transaction.from({
    type: 2,
    chainId: request.chainId,
    nonce: request.nonce,
    maxPriorityFeePerGas: BigInt(request.maxPriorityFeePerGas),
    maxFeePerGas: BigInt(request.maxFeePerGas),
    gasLimit: BigInt(request.gasLimit),
    to: request.to,
    value: BigInt(request.value),
    data: request.data,
    accessList: request.accessList ?? [],
    ...overrides,
  });
  return {
    digest: keccak256(tx.unsignedSerialized),
    unsigned: tx.unsignedSerialized,
  };
}

function recover(digest) {
  return recoverAddress(digest, {
    r: expected.r,
    s: expected.s,
    yParity: expected.yParity,
  });
}

function main() {
  const tx = Transaction.from(expected.rawSignedTx);

  assert.equal(tx.type, 2, 'transaction must be EIP-1559 type 2');
  assert.equal(tx.chainId, BigInt(request.chainId), 'chainId');
  assert.equal(Number(tx.nonce), request.nonce, 'nonce');
  assertBigEqual(tx.maxPriorityFeePerGas, request.maxPriorityFeePerGas, 'priority fee');
  assertBigEqual(tx.maxFeePerGas, request.maxFeePerGas, 'max fee');
  assertBigEqual(tx.gasLimit, request.gasLimit, 'gas limit');
  assertHexEqual(tx.to, request.to, 'recipient');
  assertBigEqual(tx.value, request.value, 'value');
  assertHexEqual(hexlify(tx.data), request.data, 'data');
  assert.equal(tx.accessList.length, 0, 'access list');

  const digest = unsignedDigest();
  assertHexEqual(digest.unsigned, expected.unsignedPayload, 'unsigned payload');
  assertHexEqual(digest.digest, expected.digest, 'signing digest');
  assertHexEqual(tx.unsignedSerialized, expected.unsignedPayload, 'parsed unsigned payload');
  assertHexEqual(tx.hash, expected.hash, 'transaction hash');
  assertHexEqual(tx.serialized, expected.rawSignedTx, 'canonical raw bytes');
  assertHexEqual(tx.signature.r, expected.r, 'r');
  assertHexEqual(tx.signature.s, expected.s, 's');
  assert.equal(tx.signature.yParity, expected.yParity, 'yParity');

  const recovered = recover(expected.digest);
  assertHexEqual(recovered, expected.from, 'recovered signer');

  // Field-binding proof: changing any signed field changes the digest, and the
  // same signature then recovers to a different address (not the cold signer).
  const substitutions = {
    chainId: 97,
    nonce: request.nonce + 1,
    maxPriorityFeePerGas: BigInt(request.maxPriorityFeePerGas) - 1n,
    maxFeePerGas: BigInt(request.maxFeePerGas) + 1n,
    gasLimit: BigInt(request.gasLimit) + 1n,
    to: '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
    value: BigInt(request.value) + 1n,
    data: '0x01',
  };
  for (const [field, value] of Object.entries(substitutions)) {
    const altered = unsignedDigest({ [field]: value });
    assert.notEqual(
      altered.digest.toLowerCase(),
      expected.digest.toLowerCase(),
      `${field} substitution did not change the digest`,
    );
    const wrongSigner = recover(altered.digest);
    assert.notEqual(
      wrongSigner.toLowerCase(),
      expected.from.toLowerCase(),
      `${field} substitution still recovered the expected signer`,
    );
  }

  // The raw bytes must be exactly 0x02 || RLP, not a re-encoded equivalent.
  const bytes = getBytes(expected.rawSignedTx);
  assert.equal(bytes[0], 0x02, 'typed envelope marker');

  console.log('independent ethers verification: PASS');
  console.log(`  signer:   ${recovered}`);
  console.log(`  tx hash:  ${tx.hash}`);
  console.log(`  digest:   ${digest.digest}`);
  console.log(`  fields:   ${Object.keys(substitutions).length} substitution checks rejected`);
}

try {
  main();
} catch (error) {
  console.error('independent ethers verification: FAIL');
  console.error(error);
  process.exitCode = 1;
}
