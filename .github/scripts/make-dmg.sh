#!/usr/bin/env bash
# Crée l'installeur .dmg : une fenêtre avec l'app, le dossier Applications et le fond de
# .github/assets/dmg-background*.png (make dmg-background), où l'on glisse l'app sur Applications.
#   .github/scripts/make-dmg.sh "build/Mac Remote Control.app" dist/MacRemoteControl-x.y.z.dmg
#
# La mise en page est faite par le Finder (AppleScript) : la première fois, macOS demande
# d'autoriser le Terminal à contrôler le Finder.
set -euo pipefail

APP="$1"
DMG="$2"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="$(cat "$ROOT/VERSION")"
VOLNAME="Mac Remote Control $VERSION"
APP_NAME="$(basename "$APP")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Contenu du disque : l'app, un raccourci vers Applications et le fond (caché, 1x et Retina).
mkdir -p "$WORK/src/.background"
ditto "$APP" "$WORK/src/$APP_NAME"
ln -s /Applications "$WORK/src/Applications"
tiffutil -cathidpicheck "$ROOT/.github/assets/dmg-background.png" "$ROOT/.github/assets/dmg-background@2x.png" \
  -out "$WORK/src/.background/background.tiff" 2>/dev/null

# Image modifiable (avec un peu de place pour le .DS_Store du Finder), mise en page, puis compressée.
SIZE_MB=$(($(du -sm "$WORK/src" | cut -f1) + 20))
hdiutil create -volname "$VOLNAME" -srcfolder "$WORK/src" -fs HFS+ -format UDRW -size "${SIZE_MB}m" "$WORK/rw.dmg" >/dev/null
MOUNT="$(hdiutil attach "$WORK/rw.dmg" -readwrite -noverify -noautoopen | awk -F '\t' '/\/Volumes\// { print $NF }')"
# Si un disque du même nom est déjà monté, macOS ajoute un suffixe (« … 1 ») : c'est ce nom qui compte.
DISK="$(basename "$MOUNT")"

# Taille de la fenêtre et position des icônes : les mêmes que dans make-dmg-background.swift
# (fenêtre de 640 × 380 points plus la barre de titre de 32 points ; centres des icônes).
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$DISK"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 120, 840, 532}
    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set text size of viewOptions to 13
    set background picture of viewOptions to file ".background:background.tiff"
    set position of item "$APP_NAME" to {170, 155}
    set position of item "Applications" to {470, 155}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

# Le Finder écrit la mise en page dans .DS_Store, parfois avec un peu de retard.
for _ in {1..10}; do
  [ -f "$MOUNT/.DS_Store" ] && break
  sleep 1
done
[ -f "$MOUNT/.DS_Store" ] || { echo "✗ Le Finder n'a pas enregistré la mise en page de l'installeur" >&2; exit 1; }
rm -rf "$MOUNT/.fseventsd"
sync
hdiutil detach "$MOUNT" >/dev/null || { sleep 2; hdiutil detach -force "$MOUNT" >/dev/null; }

hdiutil convert "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG" >/dev/null
