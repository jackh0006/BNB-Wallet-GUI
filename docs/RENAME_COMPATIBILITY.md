# X Wallet Rename and Compatibility

**Product:** X Wallet
**Version:** `1.1.0+5`
**Date:** 2026-11-06

This rename changes the user-facing product identity while preserving the
identifiers that existing wallets, backups, installations, and update paths
depend on.

## Renamed

| Area | Legacy state | Current |
|---|---|---|
| Product name | Legacy display identity (retired) | X Wallet |
| Window/header title | Legacy display identity (retired) | X Wallet |
| Localized `appTitle` (6 locales) | Legacy display identity (retired) | X Wallet |
| Android display label | Legacy display identity (retired) | X Wallet |
| Desktop entry | `bnb-wallet.desktop` | `x-wallet.desktop`, Name=X Wallet |
| Debian package | `bnb-wallet` | `x-wallet` (with compatibility fields) |
| Primary launcher | `/usr/bin/bnb-wallet` | `/usr/bin/x-wallet`; `/usr/bin/bnb-wallet` remains a symlink |
| Icons | `assets/icon/bnb-wallet-*` (historical) | `assets/icon/x-wallet-*` |
| Documentation | Legacy display identity (retired) | X Wallet throughout |

## Preserved intentionally

| Identifier | Value | Why |
|---|---|---|
| Dart package | `bnb_wallet_gui` | Import identity; changing it touches 63 files with no user benefit |
| Linux binary | `bnb_wallet_gui` | Installed bundle/launcher compatibility |
| Android application ID | `com.jackh0006.bnbwallet` | Update lineage and user data |
| Android namespace | `com.jackh0006.bnb_wallet_gui` | Build identity |
| Vault magic | `BNBVL004` / `BNBVL003` | Existing vaults must decrypt |
| Vault filenames | `bnb-wallet-vault.bnb` etc. | Existing data discovery |
| Device secret key | `device_secret_v2` | Existing devices must unlock |
| Receipt/log envelopes | `BNBRCPT1`, `BNBLOG01` | Existing archives |
| User data directory | `~/.local/share/bnb-wallet` | Upgrade must preserve the vault |
| Env vars | `BNB_*` | CI and release-script compatibility |
| GitHub repository | `X-Wallet` | Renamed; the old URL redirects and PRs, releases and tags are preserved |
| Historical tags/releases | `v1.0.5`, `v1.0.8-*`, `v1.0.9-*` | Do not rewrite public history |

## Debian migration

`scripts/build-deb.sh` emits `Package: x-wallet` with:

```
Provides: bnb-wallet
Replaces: bnb-wallet
Conflicts: bnb-wallet
```

The package installs to `/usr/lib/x-wallet`, provides `/usr/bin/x-wallet`, and
keeps `/usr/bin/bnb-wallet` as a symlink. The user-data path is unchanged.

`scripts/package-smoke.sh` must verify:

1. Install the old `bnb-wallet` 1.0.9 package.
2. Create a data marker under `~/.local/share/bnb-wallet`.
3. Install `x-wallet-1.1.0-amd64.deb`.
4. Confirm the old package is replaced, the marker survives, and `x-wallet`
   launches.
5. Uninstall `x-wallet`; reinstall it.

An upgrade that fails any of these steps blocks release.

## GitHub repository name

The GitHub repository is now `X-Wallet` at
<https://github.com/jackh0006/X-Wallet>. The previous repository URL redirects,
and PRs, releases, tags, and assets remain reachable. This rename changes no
package, binary, application ID, vault, backup, data-path, or
environment-variable identifier.

## Historical documents

Historical records use the X Wallet name throughout. Literal old package
filenames, tags, and technical identifiers remain only where they identify
real historical artifacts or preserved compatibility contracts.
`scripts/check_branding.py` enforces the X Wallet display identity and the
preserved technical identifiers.
