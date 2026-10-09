#!/usr/bin/env bash
# Construit l'interface web, compile l'app Swift et assemble build/MacRemote.app (signée).
#
#   ./scripts/build.sh            Développement : architecture du Mac, certificat « Apple Development »
#   ./scripts/build.sh release    Distribution : app universelle (Apple Silicon + Intel),
#                                 certificat « Developer ID Application », runtime renforcé (notarisation)
set -euo pipefail

MODE="${1:-dev}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/MacRemote.app"
BUNDLE_ID="dev.lukas.macremote"
VERSION="$(cat "$ROOT/VERSION")"
BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)"

case "$MODE" in
  dev | release) ;;
  *) echo "Mode inconnu : $MODE (dev ou release)" >&2; exit 1 ;;
esac

echo "▸ Interface web (Next.js, export statique)"
cd "$ROOT/web"
if [ "$MODE" = release ]; then npm ci; else [ -d node_modules ] || npm install; fi
npm run build

echo "▸ App Mac (Swift, release)"
cd "$ROOT/mac"
if [ "$MODE" = release ]; then
  SWIFT_ARGS=(-c release --arch arm64 --arch x86_64)
else
  SWIFT_ARGS=(-c release)
fi
swift build "${SWIFT_ARGS[@]}"
BIN="$(swift build "${SWIFT_ARGS[@]}" --show-bin-path)/MacRemote"

echo "▸ Assemblage de $APP ($VERSION, build $BUILD_NUMBER)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MacRemote"
cp -R "$ROOT/web/out" "$APP/Contents/Resources/web"
cp "$ROOT/mac/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>Mac Remote</string>
  <key>CFBundleDisplayName</key><string>Mac Remote</string>
  <key>CFBundleExecutable</key><string>MacRemote</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

if [ "$MODE" = release ]; then
  # Notarisation : certificat Developer ID, runtime renforcé et horodatage obligatoires.
  IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Developer ID Application/ { print $2; exit }')}"
  if [ -z "$IDENTITY" ]; then
    echo "✗ Aucun certificat « Developer ID Application » trouvé (nécessaire pour distribuer l'app)." >&2
    exit 1
  fi
  echo "▸ Signature Developer ID ($IDENTITY)"
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
  codesign --verify --strict --verbose=1 "$APP"
else
  # Signer avec « Apple Development » garde la permission Accessibilité d'un build à l'autre
  # (en signature ad hoc, macOS la redemande à chaque build).
  IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Apple Development/ { print $2; exit }')}"
  if [ -n "$IDENTITY" ]; then
    echo "▸ Signature ($IDENTITY)"
    codesign --force --sign "$IDENTITY" "$APP"
  else
    echo "▸ Pas de certificat Apple Development : signature ad hoc"
    codesign --force --sign - "$APP"
  fi
fi

echo "✓ $APP"
echo "  Lancer : open \"$APP\""
