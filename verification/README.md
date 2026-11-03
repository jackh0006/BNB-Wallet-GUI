# Independent cold-signing verification

This directory is deliberately separate from the Flutter code. It uses
**ethers.js 6.13.2** — not web3dart — to parse the exact signed bytes emitted
by the Dart cold-wallet codec and to recover the signer with an independent
secp256k1 implementation.

```sh
cd verification
npm ci
node verify.cjs
```

What is checked:

1. The typed envelope marker is `0x02` (EIP-1559).
2. The parsed chain ID, nonce, fees, gas limit, recipient, value, data and
   access list match the fixture.
3. The canonical unsigned payload and `keccak256` signing digest match exactly.
4. The raw signed transaction and transaction hash match byte-for-byte.
5. `r`, `s` and `yParity` match.
6. `recoverAddress` returns the expected synthetic signer.
7. Changing any of eight signed fields produces a different digest and a
   different recovered signer, demonstrating field binding.

The key in the fixture is the well-known public Hardhat/Anvil test mnemonic
(`test test ... junk`). It has no funds and is never used by the app. No private
key is stored in this directory; only the resulting public signed transaction.

The fixture's expected values were produced by the Dart implementation and
independently reproduced by ethers. This is an implementation cross-check, not
a third-party security audit.
