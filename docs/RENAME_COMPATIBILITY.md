# X Wallet Rename and Compatibility

**Product:** X Wallet
**Version:** `1.1.0+5`
**Date:** 2026-11-06

This rename changes the user-facing product identity while preserving the
identifiers that existing wallets, backups, installations, and update paths
depend on.

## Renamed

| Area | Before | After |
|---|---|---|
| Product name | BNB Wallet | X Wallet |
| Window/header title | BNB Wallet | X Wallet |
| Localized `appTitle` (6 locales) | BNB Wallet / translated variants | X Wallet |
| Android display label | BNB Wallet | X Wallet |
| Desktop entry | `bnb-wallet.desktop`, Name=BNB Wallet | `x-wallet.desktop`, Name=X Wallet |
| Debian package | `bnb-wallet` | `x-wallet` (with compatibility fields) |
| Primary launcher | `/usr/bin/bnb-wallet` | `/usr/bin/x-wallet`; `/usr/bin/bnb-wallet` remains a symlink |
| Icons | `assets/icon/bnb-wallet-*` | `assets/icon/x-wallet-*` |
| Documentation | BNB Wallet | X Wallet (historical releases retained) |

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
| GitHub repository | `BNB-Wallet-GUI` → `X-Wallet` | Old URL redirects; PRs, releases and tags preserved |
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

The GitHub repository was renamed from `BNB-Wallet-GUI` to `X-Wallet` after
the 1.1.0 publication. GitHub redirects the old URL, and PRs, releases, tags,
and assets remain reachable. The canonical URL is now
<https://github.com/jackh0006/X-Wallet>. This rename changes no package,
binary, application ID, vault, backup, data-path, or environment-variable
identifier.

## Historical documents

`docs/releases/1.0.9.md`, `docs/releases/1.0.10.md`, the 2026-11-04 audit,
the historical baseline, and the Android incident record retain the old name
because they describe events before the rename. `scripts/check_branding.py`
allowlists only those files.
