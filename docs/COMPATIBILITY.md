# Platform Compatibility

**Date:** 2026-11-06
**Source commit:** `3aef4b908fded5e92823c76f02d4016265c8bf12`

Status labels are strict: **IMPLEMENTED**, **BUILT**, **INSTALLED**,
**LAUNCHED**, **FUNCTIONAL**, **SUPPORTED**. A platform that only compiles is
not supported.

| Platform | Arch | Package | Build | Install | Launch | Functional | Status |
|---|---|---|---|---|---|---|---|
| Ubuntu 24.04.5 LTS | x86_64 | `.deb` / source | PASS (`flutter build linux --release`, 2m03s) | NOT TESTED | NOT TESTED | NOT TESTED | BUILD + PACKAGE ONLY |
| Debian 12 | x86_64 | `.deb` / source | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| Fedora 40 | x86_64 | source | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| Linux | arm64 | source | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| Windows | x86_64 | source | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| macOS | arm64/x86_64 | source | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| Android | arm64-v8a | `.apk` | BLOCKED | BLOCKED | BLOCKED | BLOCKED | BLOCKED (signing incident) |

## Recorded environment

- Host: Ubuntu 24.04.5 LTS, kernel `7.0.0-42-generic`, x86_64, 2 cores,
  3.8 GiB RAM.
- Flutter 3.47.6 stable; Dart 3.13.5.
- Linux release bundle and `.deb` built; package dependencies now include
  `libsecret-1-0`, `liblzma5`, `libstdc++6`.
- No clean desktop or container base image was available, so install/launch
  remains untested. Docker could not pull `ubuntu:24.04` because the environment
  proxy was unreachable.

## Hardware wallets

No Ledger, Trezor, or SafePal integration exists. The hardware matrix is a
design note, not a compatibility claim; every entry is `NOT IMPLEMENTED`. See
`docs/hardware/COMPATIBILITY_MATRIX.md`.

## Adding a platform

A platform is added to the supported table only after a recorded build,
install, launch, and functional test from the exact candidate commit. Do not
infer support from source compatibility.
