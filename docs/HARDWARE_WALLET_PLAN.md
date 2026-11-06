# Hardware Wallet Plan

**Status: NOT IMPLEMENTED.** No Ledger/Trezor integration exists, no physical
device has been tested, and no firmware matrix is verified. This document is a
requirements plan, not a support claim.

## Why it matters

A local hot wallet keeps the signing key in process memory on a general-purpose
computer. For meaningful holdings, the key must remain inside a dedicated
hardware security boundary and the transaction must be reviewed on a trusted
display.

## Candidate devices

- Ledger Nano S Plus / Nano X / Flex / Stax — Ethereum app, EIP-1559.
- Trezor Model T / Safe 3 / Safe 5 — Ethereum support.
- Any device must be pinned to a documented firmware version.

Do not list a device as supported until the exact firmware and app version
pass the tests below.

## Required implementation

1. Device discovery and transport (USB HID/BLE) with bounded timeouts.
2. Address verification on the device display, compared with the host.
3. Transaction review on the device: chain ID, recipient, value, fees, nonce,
   calldata, and contract address.
4. Reject blind signing by default; refuse unsupported transaction types.
5. Reject chain-ID mismatch and unexpected fields.
6. Handle disconnect, user cancel, busy device, wrong app, and firmware mismatch
   safely, without falling back to software signing.
7. Never send the seed, private key, or vault password to the device or host.
8. Record the device model, firmware, app version, and transport in evidence.

## Test matrix (physical device required)

| Test | Pass condition |
|---|---|
| Address verification | Device display matches host-derived address |
| Native transfer | Device reviews and signs; host verifies signature and chain |
| ERC-20 transfer | Token contract, recipient, amount, decimals shown correctly |
| Wrong chain | Device/host refuses |
| Wrong account | Refuses or requires explicit account selection |
| User cancel | No signature, no broadcast |
| Disconnect mid-sign | No signature; host reports failure |
| Malformed device response | Host fails closed |
| Firmware mismatch | Refuses or warns, never silently proceeds |
| Blind-signing request | Refused by default |
| Replay/substitution | Host rejects altered signed bytes |

## Current blocker

No physical devices are available in this environment. The project must remain
**NOT READY for large-value custody** until implementation and physical tests
are complete, followed by an independent review.
