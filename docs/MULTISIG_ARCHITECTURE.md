# Multisignature Custody Architecture

**Status: NOT IMPLEMENTED.** This project does not deploy or claim a
multisignature wallet. This document defines the architecture and the evidence
required before any such claim.

## Principle

A single compromised computer, device, or operator must not be able to move
significant funds. Approval must require independent signers or devices.

## Recommended approach

Use an established, independently reviewed multisignature system on BNB Smart
Chain (for example a reviewed Safe deployment). Do not deploy a custom
multisignature contract for valuable funds without a professional audit.

## Required properties

1. **Signer independence.** Keys are held on separate hardware devices, by
   separate people or recovery domains.
2. **Threshold.** At least 2-of-3 or 3-of-5 for significant holdings; a single
   signer cannot move funds.
3. **On-device review.** Each signer verifies chain, recipient, amount, and
   calldata before signing.
4. **Transaction hash verification.** Signers compare the Safe transaction hash
   through an independent channel.
5. **Recovery.** A documented process for a lost signer, compromised signer, or
   lost device, tested without moving real funds.
6. **Signer replacement.** A reviewed, delayed procedure; no single signer can
   silently replace the set.
7. **Operational controls.** Address allowlists, spending limits, delay windows,
   and an incident runbook.
8. **Independent review.** Contract, client, and operational procedure reviewed
   by a qualified external party.

## What this project may claim now

- It can construct and sign a normal EIP-1559 transaction locally.
- It can act as one signer in a manually operated external workflow only if the
  user independently verifies the Safe transaction hash and destination.
- It does **not** implement Safe transaction construction, threshold collection,
  or multisignature verification.

## Required before claiming support

- A reviewed multisig implementation and deployment on BSC.
- Integration tests against a local Safe deployment.
- Physical signer separation tests.
- Recovery and signer-replacement drills.
- Independent audit of the integration and operational procedure.

Until then, the correct status is **NOT READY for large-value custody**.
