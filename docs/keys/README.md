# X Wallet Release Signing Key

**Fingerprint:** `CC819EF5E109A1518E840379D8C0CEC84BCCE06B`
**Key ID:** `D8C0CEC84BCCE06B`
**Algorithm:** EdDSA
**Owner:** `jackh0006 <jackh109867@gmail.com>`

The public key is stored in `x-wallet-signing-key.asc`. Import it and compare
the fingerprint through an independent channel before trusting a signature.

```bash
gpg --import x-wallet-signing-key.asc
gpg --fingerprint CC819EF5E109A1518E840379D8C0CEC84BCCE06B
gpg --verify SHA256SUMS.asc SHA256SUMS
```

Only the public key belongs here. Never commit a private key or passphrase.
