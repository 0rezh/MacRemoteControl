#!/usr/bin/env bash
# Construit l'installeur à publier sur GitHub : dist/MacRemoteControl-<version>.dmg
#   1. app universelle signée Developer ID (.github/scripts/build.sh release)
#   2. notarisation de l'app par Apple, ticket agrafé à l'app
#   3. .dmg (glisser l'app dans Applications), signé, notarisé, ticket agrafé
#
# Prérequis (une seule fois) : un profil de notarisation dans le trousseau, voir CONTRIBUTING.md.
#   NOTARY_PROFILE=autre-nom make release   pour utiliser un autre profil
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="$(cat "$ROOT/VERSION")"
NOTARY_PROFILE="${NOTARY_PROFILE:-mac-remote-notary}"
APP="$ROOT/build/Mac Remote Control.app"
DIST="$ROOT/dist"
DMG="$DIST/MacRemoteControl-$VERSION.dmg"

if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  NOTARIZE=1
else
  NOTARIZE=0
  echo "⚠︎ Profil de notarisation « $NOTARY_PROFILE » introuvable : l'installeur sera signé mais pas notarisé"
  echo "  (macOS affichera un avertissement à l'ouverture). Voir CONTRIBUTING.md › Publier une version."
fi

notarize() {
  xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
}

"$ROOT/.github/scripts/build.sh" release
IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Developer ID Application/ { print $2; exit }')}"

rm -rf "$DIST"
mkdir -p "$DIST/dmg"

if [ "$NOTARIZE" = 1 ]; then
  echo "▸ Notarisation de l'app"
  ditto -c -k --keepParent "$APP" "$DIST/MacRemoteControl.zip"
  notarize "$DIST/MacRemoteControl.zip"
  xcrun stapler staple "$APP"
  rm "$DIST/MacRemoteControl.zip"
fi

echo "▸ Création de l'installeur $DMG"
ditto "$APP" "$DIST/dmg/Mac Remote Control.app"
ln -s /Applications "$DIST/dmg/Applications"
hdiutil create -volname "Mac Remote Control $VERSION" -srcfolder "$DIST/dmg" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$DIST/dmg"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

if [ "$NOTARIZE" = 1 ]; then
  echo "▸ Notarisation de l'installeur"
  notarize "$DMG"
  xcrun stapler staple "$DMG"
  spctl --assess --type open --context context:primary-signature --verbose "$DMG"
fi

echo
echo "✓ $DMG"
shasum -a 256 "$DMG"
echo
echo "Publier sur GitHub :"
echo "  gh release create v$VERSION \"$DMG\" --title \"Mac Remote Control $VERSION\" --generate-notes"
