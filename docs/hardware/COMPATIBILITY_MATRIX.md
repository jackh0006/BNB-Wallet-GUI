# COMPATIBILITY_MATRIX.md — Hardware Wallet Compatibility

**Date**: 2026-11-03 (status corrected 2026-11-06)
**Baseline Commit**: `68091b06cce3e9c90692e3f632d539ae69734154`
**Status**: **NO HARDWARE-WALLET INTEGRATION EXISTS IN THE CODE. This document
is a future design note, not evidence of compatibility. Every device below is
`NOT IMPLEMENTED`, not merely "untested".**

---

## Compatibility Status Legend

| Status | Meaning |
|--------|---------|
| **VERIFIED** | Tested with physical device; all claimed features work |
| **PARTIAL** | Tested; some features work, limitations documented |
| **NOT TESTED** | Code exists but no physical verification |
| **NOT IMPLEMENTED** | No code path exists; do not claim support |
| **NOT SUPPORTED** | Intentionally not implemented |
| **BLOCKED** | Known issue preventing support |

---

## Ledger Devices

| Model | Firmware | Transport | Linux udev | Android USB | EVM App | Sign Types | Status |
|-------|----------|-----------|------------|-------------|---------|------------|--------|
| **Nano S** | ≥ 2.0 | USB HID | Required | ❌ | Ethereum | EIP-1559, Legacy, ERC-20 | NOT IMPLEMENTED |
| **Nano S Plus** | ≥ 1.0 | USB HID | Required | ❌ | Ethereum | EIP-1559, Legacy, ERC-20 | NOT IMPLEMENTED |
| **Nano X** | ≥ 2.0 | USB HID / BLE | Required | BLE | Ethereum | EIP-1559, Legacy, ERC-20 | NOT IMPLEMENTED |
| **Stax** | ≥ 1.0 | USB HID / BLE | Required | BLE | Ethereum | EIP-1559, Legacy, ERC-20, EIP-712 | NOT IMPLEMENTED |
| **Flex** | ≥ 1.0 | USB HID / BLE | Required | BLE | Ethereum | EIP-1559, Legacy, ERC-20, EIP-712 | NOT IMPLEMENTED |

**Linux udev rule needed** (for all Ledger):
```udev
SUBSYSTEM=="usb", ATTR{idVendor}=="2c97", TAG+="uaccess"
```

**Android**: Nano S/X not supported via USB (no WebUSB in Chrome for this); Nano X/Flex/Stax via BLE if app supports.

---

## Trezor Devices

| Model | Firmware | Transport | Linux udev | Android USB | EVM Support | Sign Types | Status |
|-------|----------|-----------|------------|-------------|-------------|------------|--------|
| **Model One** | ≥ 2.4 | USB HID | Required | ❌ | Ethereum (via Trezor Bridge/Suite) | EIP-1559, Legacy | NOT IMPLEMENTED |
| **Model T** | ≥ 2.4 | USB HID | Required | WebUSB | Ethereum | EIP-1559, Legacy, ERC-20, EIP-712 | NOT IMPLEMENTED |
| **Safe 3** | ≥ 1.0 | USB HID | Required | WebUSB | Ethereum | EIP-1559, Legacy, ERC-20, EIP-712 | NOT IMPLEMENTED |
| **Safe 5** | ≥ 1.0 | USB HID / NFC | Required | WebUSB/NFC | Ethereum | EIP-1559, Legacy, ERC-20, EIP-712 | NOT IMPLEMENTED |

**Linux udev rule needed** (for all Trezor):
```udev
SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="5320|5321|0001|0002", TAG+="uaccess"
```

**Android**: Model T/Safe 3/Safe 5 via WebUSB in Chrome; Model One not supported on Android.

---

## SafePal Devices

| Model | Firmware | Transport | Linux | Android | EVM Support | Sign Types | Status |
|-------|----------|-----------|-------|---------|-------------|------------|--------|
| **S1** | ≥ 4.0 | QR / Bluetooth | ❌ | Bluetooth | BSC/Ethereum | EIP-1559, Legacy | NOT IMPLEMENTED |
| **X1** | ≥ 1.0 | QR / Bluetooth / NFC | ❌ | Bluetooth/NFC | BSC/Ethereum | EIP-1559, Legacy | NOT IMPLEMENTED |

**Note**: SafePal uses air-gapped QR signing primarily; Bluetooth for app pairing. No USB/HID.

**Linux**: No official desktop support; QR flow only.

---

## Integration Architecture (Planned)

```
HardwareWalletManager
├── LedgerTransport (HID + BLE)
│   ├── Linux: hidapi + udev
│   ├── Android: USB host + BLE GATT
│   └── App: Ethereum app (contract data, EIP-1559)
├── TrezorTransport (HID + WebUSB)
│   ├── Linux: hidapi + udev
│   ├── Android: WebUSB (Chrome)
│   └── Firmware: Ethereum support
└── SafePalTransport (QR + BLE)
    ├── QR: Animated QR encoding/decoding
    └── BLE: GATT pairing + signing
```

**Common Interface**:
```dart
abstract class HardwareWallet {
  Future<List<DerivedAccount>> getAccounts({required int count});
  Future<SignedTransaction> signTransaction({
    required Transaction tx,
    required int accountIndex,
    required int chainId,
  });
  Future<bool> verifyAddress({required String address, required int accountIndex});
  String get deviceLabel;
  FirmwareVersion get firmwareVersion;
}
```

---

## Test Plan (When Devices Available)

| Test | Description | Pass Criteria |
|------|-------------|---------------|
| **Device Detection** | Enumerate connected devices | Correct model, firmware, transport shown |
| **Account Derivation** | Request first 5 accounts | Matches BIP-44 m/44'/60'/0'/0/i |
| **Address Verification** | Show address on device screen | User confirms match |
| **Native Transfer Sign** | Sign BNB transfer (EIP-1559) | Valid signature, correct nonce |
| **ERC-20 Transfer Sign** | Sign USDT/USDC transfer | Correct calldata, valid signature |
| **EIP-1559 Fee Parity** | Compare fee with software wallet | Same gas, fee parameters |
| **Chain ID Validation** | Sign on wrong chain | Device rejects / shows mismatch |
| **Replay Protection** | Same nonce twice | Second rejected |
| **Bluetooth/BLE Stability** | 10 consecutive signs | No disconnects |
| **QR Flow (SafePal)** | Animated QR sign + import | Valid transaction, verified |

---

## Evidence Template (Per Device)

When tested, record:

```markdown
## [Model] — Test Report

**Date**: YYYY-MM-DD
**Firmware**: X.Y.Z
**Transport**: USB HID / BLE / WebUSB / QR
**OS**: Ubuntu 24.04 / Android 14
**App Version**: 1.0.x

### Results
| Test | Pass/Fail | Notes |
|------|-----------|-------|
| Detection | | |
| Account Derivation | | |
| Address Verification | | |
| Native Transfer | | |
| ERC-20 Transfer | | |
| EIP-1559 Parity | | |
| Chain ID Validation | | |
| Replay Protection | | |
| Transport Stability | | |

### Limitations Found
- 

### Evidence
- Photos of device screens
- Packet captures (if applicable)
- Signed transaction hashes (testnet)
```

---

## Current Implementation Status

| Component | Status |
|-----------|--------|
| **HardwareWalletManager** | NOT STARTED |
| **Ledger HID transport** | NOT STARTED |
| **Ledger BLE transport** | NOT STARTED |
| **Trezor HID transport** | NOT STARTED |
| **Trezor WebUSB transport** | NOT STARTED |
| **SafePal QR transport** | NOT STARTED |
| **SafePal BLE transport** | NOT STARTED |
| **Common signing interface** | NOT STARTED |
| **Account derivation UI** | NOT STARTED |
| **Transaction review on device** | NOT STARTED |
| **udev rules packaging** | NOT STARTED |
| **Android USB/Bluetooth permissions** | NOT STARTED |

---

## Security Requirements for Integration

1. **Private keys never leave device** — enforced by hardware
2. **Transaction details shown on device screen** — user must verify
3. **No seed phrase entry in app** — hardware wallet setup only
4. **Chain ID validated on device** — mismatch = rejection
5. **Transport encryption** — HID/WebUSB/BLE encrypted where supported
6. **No fallback to software signing** — if hardware unavailable, show error

---

*This document is a design note. No hardware-wallet transport is implemented
in the current source; every entry is `NOT IMPLEMENTED`, not "untested".*