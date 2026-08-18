#!/usr/bin/env bash
# scripts/setup-signing.sh
# Run this ONCE on your dev machine to generate the release signing keystore.
# It creates android/app/upload-keystore.jks + android/key.properties (both gitignored)
# and prints the values you need to paste into GitHub Secrets.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=== Flutter Android signing setup ==="
echo "This generates a release keystore locally. It will NOT be committed."
echo

read -s -p "Enter a keystore password: " STORE_PASS; echo
read -s -p "Enter a key password (can be same): " KEY_PASS; echo
read -p "Key alias [upload]: " KEY_ALIAS
KEY_ALIAS="${KEY_ALIAS:-upload}"

KEYSTORE="android/app/upload-keystore.jks"
mkdir -p android/app

echo
echo "Generating keystore with keytool..."
keytool -genkey -v \
  -keystore "$KEYSTORE" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias "$KEY_ALIAS" \
  -storepass "$STORE_PASS" -keypass "$KEY_PASS" \
  -dname "CN=Flutter App, OU=Dev, O=Example, L=Shenzhen, ST=Guangdong, C=CN"

cat > android/key.properties <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=$KEY_ALIAS
storeFile=upload-keystore.jks
EOF

echo
echo "=== Done. Files created (gitignored): ==="
echo "  $KEYSTORE"
echo "  android/key.properties"
echo
echo "=== Verify a release build signs correctly: ==="
echo "  flutter build apk --release"
echo
echo "=== GitHub Secrets to add (repo > Settings > Secrets and variables > Actions): ==="
echo "  ANDROID_KEY_ALIAS         = $KEY_ALIAS"
echo "  ANDROID_KEYSTORE_PASSWORD = <the keystore password you just entered>"
echo "  ANDROID_KEY_PASSWORD      = <the key password you just entered>"
echo
echo "  ANDROID_KEYSTORE_BASE64   = (copy the base64 below)"
# base64 -w0 works on GNU (Git Bash/Linux); macOS base64 needs no -w
if base64 -w0 "$KEYSTORE" >/dev/null 2>&1; then
  base64 -w0 "$KEYSTORE"
else
  base64 "$KEYSTORE" | tr -d '\n'
fi
echo
echo
echo "Next: create a Google Play service account JSON for PLAY_SERVICE_ACCOUNT_JSON"
echo "(only needed when you want auto-upload to Play Store on tags)."
