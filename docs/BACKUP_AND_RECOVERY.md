# Backup and Recovery

**Scope:** the encrypted local vault and its device-bound wrapper. Recovery is
not possible from the vault alone if the device secret is lost; the recovery
phrase is the real backup.

## What is backed up

- Encrypted vault file: `bnb-wallet-vault.bnb` (`BNBVL004` v2).
- Encrypted receipt archive and activity log are local; they are not required
  to recover funds.
- The device secret is **not** in the backup. It lives in the platform secure
  store or the Linux owner-only drawer.

## Canonical recovery procedure

1. Stop the wallet.
2. Keep the original vault file untouched.
3. On a clean installation, choose **Import wallet → recovery phrase**.
4. Enter the 12/24 words in the correct order. Never type them into a website,
   chat, terminal, or support message.
5. Confirm the derived address against an independent record.
6. Send a small test amount before relying on the restored wallet.

Do not restore by copying only the vault file to another machine: the
device-bound wrapper will not open without that machine's device secret, by
design.

## Backup verification

- The encrypted backup export must decrypt with the same password and device
  secret.
- A failed export must never replace a known-good backup.
- A failed import must leave the original vault byte-identical; this is covered
  by `test/vault_import_rollback_kdf_test.dart`.
- A wrong password, truncated file, corrupted tag, or modified header must fail
  closed with a generic error.

## Tested

- Vault v2 round-trip, wrong password, wrong device secret, fresh nonce.
- v1 migration and truncated-header rejection.
- Atomic write, rollback injection, post-commit verification failure.
- Import rollback and concurrent serialization.

## Not tested

- End-to-end UI restore on a clean machine.
- Disk-full and power-loss recovery on a physical device.
- Backup media failure and long-term paper degradation.

## Recovery limitations

- There is no support recovery, no key escrow, and no password reset.
- Losing both the recovery phrase and the vault password loses the funds.
- A compromised OS can capture the phrase while it is displayed.
- Do not store the phrase in a photo, cloud note, password manager, or chat.
