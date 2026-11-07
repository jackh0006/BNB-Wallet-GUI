# Transaction Security

**Scope:** native-coin and EVM token transfers as enabled in 1.1.0. The wallet does not implement
token approvals, arbitrary contract calls, or a dapp browser.

## Flow

1. User enters network, recipient, amount, token, and fee tier.
2. Recipient is validated (EIP-55/hex, non-zero, contract detection).
3. Amount is parsed as integer base units; floating point is never used.
4. Fees are read from the selected node; EIP-1559 and legacy modes are
   explicit.
5. A simulation (`eth_call`) is performed; it is advisory, not a guarantee.
6. The review screen shows network, full recipient, amount, token, contract,
   fees, maximum total, and calldata.
7. Hold-to-confirm (pointer or keyboard Space/Enter) is required.
8. `SendIntent.verify` re-checks every field immediately before signing.
9. The transaction is signed locally with the reviewed chain ID.
10. Broadcast result is classified; an ambiguous transport failure is treated
    as an unknown outcome and is **not** automatically retried.
11. The receipt/status is reconciled against the node and explorer.

## Invariants

- Chain ID is validated on connect and bound into the signature.
- Native transfers: exact recipient, exact value, empty calldata.
- BEP-20 transfers: exact contract, zero value, exact 4+32+32-byte calldata,
  exact recipient and amount.
- Trailing calldata is rejected.
- Token decimals are bounded; unknown metadata is displayed as unverified.
- Address poisoning produces a heuristic warning; it is never called proof.
- Zero address is rejected.
- Integer amounts are `BigInt`; no floating point.
- A changed field after review refuses signing.
- A duplicate or already-known broadcast is not resent blindly.
- An approval screen does not exist; therefore unlimited allowances cannot be
  granted through this UI. If approvals are added, they require a cap and a
  separate security review.

## Tests

- `test/send_intent_test.dart` — exact calldata, field substitution, fees,
  chain, zero-address.
- `test/fee_engine_test.dart`, `test/fee_parity_test.dart` — fee math.
- `test/tx_lifecycle_test.dart` — stages, ambiguous outcomes, revert decoding.
- `test/rpc_adversarial_test.dart` — wrong chain, malformed RPC.
- `test/fuzz_and_property_test.dart` — calldata/RLP mutation.
- `test/cold_*` + `verification/verify.cjs` — offline signing and independent
  byte verification.

## Limitations

- No light-client proof; a malicious RPC can lie about balances, nonces, and
  simulation results.
- No real BSC/Anvil integration test yet.
- Contract semantics beyond a plain transfer are not decoded.
- A user can still confirm the wrong valid address.
- Simulation is not a safety guarantee.
