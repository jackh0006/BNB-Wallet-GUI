#!/usr/bin/env bash
#
# Build a signed Debian/Ubuntu amd64 .deb of BNB Wallet GUI (Linux release bundle).
#
# Output:
#   /home/mhh06/Downloads/BNB Wallet/bnb-wallet-<pubspec version>-amd64.deb
#   plus SHA256SUMS and, when BNB_GPG_KEY names an available secret key, a
#   GPG detached signature (.asc).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTDIR="/home/mhh06/Downloads/BNB Wallet"
VERSION="$(sed -n 's/^version:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' "$ROOT/pubspec.yaml" | head -1)"
VERSION="${VERSION:-0.0.0}"
DEB="$OUTDIR/bnb-wallet-${VERSION}-amd64.deb"

mkdir -p "$OUTDIR"

echo "[1/5] Building Linux release bundle ..."
cd "$ROOT"
if [ "${SKIP_FLUTTER_BUILD:-0}" != "1" ]; then
  flutter build linux --release
else
  echo "Using existing release bundle (SKIP_FLUTTER_BUILD=1)."
fi

BUNDLE="$ROOT/build/linux/x64/release/bundle"
if [ ! -x "$BUNDLE/bnb_wallet_gui" ]; then
  echo "ERROR: release bundle not found at $BUNDLE" >&2
  exit 1
fi

echo "[2/5] Staging .deb contents ..."
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

install -d "$STAGE/DEBIAN" \
  "$STAGE/usr/lib/bnb-wallet" \
  "$STAGE/usr/bin" \
  "$STAGE/usr/share/applications" \
  "$STAGE/usr/share/doc/bnb-wallet"

# Application bundle.
cp -a "$BUNDLE/." "$STAGE/usr/lib/bnb-wallet/"

# Launcher.
cat > "$STAGE/usr/bin/bnb-wallet" <<'LAUNCHER'
#!/bin/sh
# BNB Wallet launcher for Linux.
set -eu
APP_DIR="/usr/lib/bnb-wallet"
exec "$APP_DIR/bnb_wallet_gui" "$@"
LAUNCHER
chmod 0755 "$STAGE/usr/bin/bnb-wallet"

# .desktop file.
cat > "$STAGE/usr/share/applications/bnb-wallet.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=BNB Wallet
Comment=Local non-custodial BNB Smart Chain wallet
Exec=bnb-wallet
Icon=bnb-wallet
Terminal=false
Categories=Finance;Office;
Keywords=bnb;bsc;crypto;wallet;
StartupNotify=true
StartupWMClass=BNB Wallet
DESKTOP
chmod 0644 "$STAGE/usr/share/applications/bnb-wallet.desktop"

# Icons (4K source resized to standard hicolor sizes).
python3 - "$ROOT" "$STAGE" <<'PY'
import os, sys
from PIL import Image
root, stage = sys.argv[1], sys.argv[2]
src = os.path.join(root, "assets", "icon", "bnb-wallet-1024.png")
img = Image.open(src).convert("RGBA")
for size in (16, 32, 48, 64, 128, 256, 512, 1024):
    d = os.path.join(stage, "usr", "share", "icons", "hicolor",
                     f"{size}x{size}", "apps")
    os.makedirs(d, exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(
        os.path.join(d, "bnb-wallet.png"), "PNG")
PY

# control file.
cat > "$STAGE/DEBIAN/control" <<CONTROL
Package: bnb-wallet
Version: ${VERSION}
Section: finance
Priority: optional
Architecture: amd64
Maintainer: jackh0006 <jackh109867@gmail.com>
Depends: libgtk-3-0, libc6
Description: BNB Wallet — graphical BNB Smart Chain wallet
 GUI port of the BNB terminal wallet (v1). Local, non-custodial: create or
 import BIP-39 wallets, manage BNB and BEP-20 tokens, send with live EIP-1559
 / legacy fee tiers, receive with QR, inspect public addresses, manage RPC
 nodes and an encrypted local vault (Argon2id + XChaCha20-Poly1305).
 Secrets stay on-device; RPC never sees keys or phrases.
Homepage: https://github.com/jackh0006/BNB-Wallet-GUI
CONTROL
chmod 0644 "$STAGE/DEBIAN/control"

# postinst: refresh icon cache / desktop database when available.
cat > "$STAGE/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q 2>/dev/null || true
fi
exit 0
POSTINST
chmod 0755 "$STAGE/DEBIAN/postinst"

# README + security docs into doc dir.
cp "$ROOT/README.md" "$STAGE/usr/share/doc/bnb-wallet/README" 2>/dev/null || true
chmod 0644 "$STAGE/usr/share/doc/bnb-wallet/README" 2>/dev/null || true
for DOC in THREAT_MODEL SECURITY CRYPTO STANDARDS PRIVACY ARCHITECTURE \
           CONTRIBUTING CHANGELOG SPEC-COMPLIANCE FAMILY_GUIDE HARDENING_REPORT \
           RELEASE_EVIDENCE; do
  if [ -f "$ROOT/docs/$DOC.md" ]; then
    cp "$ROOT/docs/$DOC.md" "$STAGE/usr/share/doc/bnb-wallet/$DOC"
    chmod 0644 "$STAGE/usr/share/doc/bnb-wallet/$DOC"
  fi
done
# LICENSE (AGPL) + SBOM ship next to the docs.
if [ -f "$ROOT/LICENSE" ]; then
  cp "$ROOT/LICENSE" "$STAGE/usr/share/doc/bnb-wallet/LICENSE"
  chmod 0644 "$STAGE/usr/share/doc/bnb-wallet/LICENSE"
fi
for ROOT_DOC in NOTICE DONATE.md; do
  if [ -f "$ROOT/$ROOT_DOC" ]; then
    cp "$ROOT/$ROOT_DOC" "$STAGE/usr/share/doc/bnb-wallet/$ROOT_DOC"
    chmod 0644 "$STAGE/usr/share/doc/bnb-wallet/$ROOT_DOC"
  fi
done
if [ -f "$ROOT/docs/SBOM.json" ]; then
  cp "$ROOT/docs/SBOM.json" "$STAGE/usr/share/doc/bnb-wallet/SBOM.json"
  chmod 0644 "$STAGE/usr/share/doc/bnb-wallet/SBOM.json"
fi

echo "[3/5] Building $DEB ..."
dpkg-deb --build --root-owner-group "$STAGE" "$DEB"

echo "[4/5] Checking package ..."
dpkg-deb -c "$DEB" >/dev/null
dpkg-deb -I "$DEB"

echo "[5/5] Checksums and optional GPG signature ..."
sha256sum "$DEB" > "$OUTDIR/SHA256SUMS"
if [ -n "${BNB_GPG_KEY:-}" ]; then
  if ! gpg --batch --list-secret-keys --with-colons "$BNB_GPG_KEY" \
      | grep -q '^sec:'; then
    echo "ERROR: BNB_GPG_KEY does not identify an available secret signing key." >&2
    exit 1
  fi
  gpg --batch --yes --digest-algo SHA256 --default-key "$BNB_GPG_KEY" \
      --detach-sign --armor "$DEB"
  echo "GPG signature: $DEB.asc"
else
  echo "No BNB_GPG_KEY supplied; package is unsigned (SHA-256 written)." >&2
fi

echo "Done: $DEB"
echo "      $OUTDIR/SHA256SUMS"
if [ -n "${BNB_GPG_KEY:-}" ]; then
  echo "      $DEB.asc"
fi
