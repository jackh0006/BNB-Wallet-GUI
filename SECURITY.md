# Security policy

BNB Wallet is AI-assisted and self-assessed personal-use software wallet. Do
not report a security issue in a public GitHub issue and do not include seed
phrases, private keys, vault files, passwords, or live transaction data in a
report. AI assistance and self-assessment are not independent review.

## Reporting a vulnerability

Email jackh109867@gmail.com with:

- a concise description and affected version/commit;
- safe reproduction steps using only throwaway keys and a local/test network;
- impact and any suggested mitigation.

The maintainer will acknowledge reports privately, assess impact, prepare a
fix, and coordinate disclosure with the reporter. There is no bounty program.

## Security status

Automated checks, source review, and package signatures reduce risk; they do
not prove safety for real-money use. Read [SECURITY_AUDIT.md](SECURITY_AUDIT.md),
[docs/THREAT_MODEL.md](docs/THREAT_MODEL.md), and
[docs/KNOWN_LIMITATIONS.md](docs/KNOWN_LIMITATIONS.md) before use. The
version-specific pass/fail record and confirmation rule are in
[docs/RELEASE_EVIDENCE.md](docs/RELEASE_EVIDENCE.md).

## Key rotation

If a signing key, seed phrase, device, or release account is suspected
compromised, stop distributing the affected artifact. Create a replacement
identity outside the repository, publish its fingerprint through a trusted
out-of-band channel, and issue a signed release note. The historical Android
release key is compromised; it must never be reused.
