# High-Value Custody Architecture

**Status: NOT READY for large-value custody.** X Wallet is a local hot wallet.
Hardware-wallet support is not implemented and the project has no independent
security audit. See `HARDWARE_WALLET_PLAN.md` and `MULTISIG_ARCHITECTURE.md`.

This document is guidance, not a claim that the current wallet is suitable for
large holdings. X Wallet GUI is a **local hot wallet**: its signing key lives
in process memory while unlocked.

## Use the right tool

| Value at risk | Recommended custody |
|---|---|
| Testnet / learning | Local hot wallet with throwaway keys |
| Small amounts | Local hot wallet + paper backup + small test transfer |
| Meaningful savings | Hardware wallet with on-device transaction review |
| Significant / organizational | Hardware-backed multisignature with separated operators and recovery |

## Required properties for significant holdings

1. **Key isolation.** The signing key never exists on an internet-connected
   general-purpose computer.
2. **On-device verification.** The recipient, amount, chain, fee cap, and
   calldata are reviewed on a trusted display.
3. **Independent approval.** At least two independent signers or devices for a
   spend; one compromised operator cannot move funds.
4. **Recovery separation.** Recovery material is offline, geographically
   separated, and tested without exposing it to a computer.
5. **Operational controls.** Address allowlists, spending limits, delay windows,
   and an incident runbook.
6. **Independent review.** A professional review of the exact custody design,
   contracts, and operational procedure.

## Multisignature

Prefer established, independently reviewed multisignature systems with a public
security history on BNB Smart Chain. Do not deploy a custom multisignature
contract for valuable funds without a professional audit. This project does not
currently deploy or recommend a custom contract.

## What this project can honestly claim

- Local key ownership and encrypted storage.
- Exact transaction review and local signing.
- A cold-wallet request/sign/verify protocol.
- Verifiable build/test evidence.

It cannot claim:

- Hardware-backed key isolation (not implemented).
- Multisignature protection (not implemented).
- Independent audit (none performed).
- Suitability for significant holdings.

## Before funding a high-value wallet

- [ ] Independent review completed.
- [ ] Hardware wallet or multisig tested with the actual firmware/contract.
- [ ] Recovery tested on a separate clean device.
- [ ] Small-value end-to-end test completed.
- [ ] Operational runbook and emergency contacts documented.
- [ ] Software and firmware update policy defined.
