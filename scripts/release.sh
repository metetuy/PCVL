#!/bin/zsh
# Builds a Release archive and packages PCVL.app for distribution:
#   PCVL-<version>.dmg      what people download and install (drag to Applications)
#   PCVL-<version>.zip      what the in-app updater downloads
#   PCVL-<version>.zip.sig  the zip's Ed25519 signature, checked by the updater
# and optionally publishes all three as a GitHub release tagged v<version>.
#
# Before running: bump MARKETING_VERSION (the version users see, compared by the
# updater) and CURRENT_PROJECT_VERSION, commit and push. Pushing such a commit to
# main runs this on GitHub Actions (.github/workflows/release.yml) instead.
#
#   scripts/release.sh             builds, then asks before publishing (with gh)
#   scripts/release.sh --publish   builds and publishes without asking (CI)

set -euo pipefail
cd "${0:A:h}/.."

PUBLISH=false
[[ "${1:-}" == "--publish" ]] && PUBLISH=true

BUILD=build
ARCHIVE="$BUILD/PCVL.xcarchive"

# Disk image whose window shows only the app, an arrow and the Applications
# shortcut (background from dmg-background.swift). The layout needs Finder
# automation; without it the DMG still works, in Finder's default view.
make_dmg() {
    local app=$1 version=$2 output=$3
    local volume="PCVL $version"
    local staging="$BUILD/dmg" background="$BUILD/dmg-background"
    local writable="$BUILD/writable.dmg" mountpoint="/Volumes/$volume"

    rm -rf "$staging" "$background" "$writable"
    mkdir -p "$staging/.background"
    ditto "$app" "$staging/PCVL.app"
    ln -s /Applications "$staging/Applications"
    swift scripts/dmg-background.swift "$background"
    tiffutil -cathidpicheck "$background/background.png" "$background/background@2x.png" \
        -out "$staging/.background/background.tiff" 2>/dev/null

    [[ -d "$mountpoint" ]] && hdiutil detach "$mountpoint" -quiet -force
    hdiutil create -quiet -volname "$volume" -srcfolder "$staging" -fs HFS+ -format UDRW -ov "$writable"
    hdiutil attach -quiet -readwrite -noverify -noautoopen "$writable"

    osascript <<EOF >/dev/null 2>&1 || echo "  (Finder layout skipped; allow your terminal to control Finder for the arranged window)"
tell application "Finder"
    tell disk "$volume"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 760, 448}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.tiff"
        set position of item "PCVL.app" of container window to {150, 140}
        set position of item "Applications" of container window to {410, 140}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

    # The app's icon for the mounted disk. After the layout: Finder drops it otherwise.
    if [[ -f "$app/Contents/Resources/AppIcon.icns" ]] && command -v SetFile >/dev/null; then
        cp "$app/Contents/Resources/AppIcon.icns" "$mountpoint/.VolumeIcon.icns"
        SetFile -a C "$mountpoint"
    fi

    sync
    hdiutil detach "$mountpoint" -quiet || hdiutil detach "$mountpoint" -quiet -force
    rm -f "$output"
    hdiutil convert -quiet "$writable" -format UDZO -imagekey zlib-level=9 -o "$output"
    rm -rf "$staging" "$background" "$writable"
}

rm -rf "$BUILD"
mkdir -p "$BUILD"

echo "Archiving…"
xcodebuild -project PCVL.xcodeproj -scheme PCVL -configuration Release -archivePath "$ARCHIVE" archive -quiet

APP="$ARCHIVE/Products/Applications/PCVL.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
ZIP="$BUILD/PCVL-$VERSION.zip"
DMG="$BUILD/PCVL-$VERSION.dmg"

echo "Packaging…"
ditto -c -k --keepParent "$APP" "$ZIP"
swift scripts/update-signer.swift sign "$ZIP" > "$ZIP.sig"
make_dmg "$APP" "$VERSION" "$DMG"

echo
echo "Built PCVL $VERSION:"
echo "  $DMG      (download for people)"
echo "  $ZIP      (in-app updater)"
echo "  $ZIP.sig  (in-app updater)"
echo
echo "Publish all three on a GitHub release tagged v$VERSION (the tag is the version the app compares)."

NOTES="Download **PCVL-$VERSION.dmg**, open it and drag PCVL into Applications.
Already installed? PCVL updates itself (Settings › Updates).

The .zip and .zip.sig files are used by the in-app updater."

if command -v gh >/dev/null; then
    if ! $PUBLISH; then
        read "answer?Create release v$VERSION on GitHub now? [y/N] "
        [[ "$answer" == [yY] ]] && PUBLISH=true
    fi
    if $PUBLISH; then
        # On CI the tag goes on the commit that was built, not on whatever main is by then.
        gh release create "v$VERSION" "$DMG" "$ZIP" "$ZIP.sig" --title "PCVL $VERSION" --notes "$NOTES" --generate-notes \
            ${GITHUB_SHA:+--target=$GITHUB_SHA}
    fi
elif $PUBLISH; then
    echo "--publish needs the gh command." >&2
    exit 1
else
    echo "Upload them at https://github.com/metetuy/PCVL/releases/new (or install gh to do it from here)."
    echo "Suggested release notes:"
    echo
    echo "$NOTES"
fi
