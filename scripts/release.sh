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
#   scripts/release.sh --dmg-only  only rebuilds the DMG (reusing the last archive) and opens it

set -euo pipefail
cd "${0:A:h}/.."

PUBLISH=false
DMG_ONLY=false
case "${1:-}" in
    --publish) PUBLISH=true ;;
    --dmg-only) DMG_ONLY=true ;;
esac

BUILD=build
ARCHIVE="$BUILD/PCVL.xcarchive"
APP="$ARCHIVE/Products/Applications/PCVL.app"

# DMG window layout, in points. Finder (macOS 26+) draws icons ICON_DROP points
# lower than the background picture, so the arrow is drawn that much lower too.
DMG_WIDTH=640
DMG_HEIGHT=480
APP_X=180
APPLICATIONS_X=460
ICON_Y=180
ICON_DROP=45

# Disk image whose window shows only the app, an arrow and the Applications
# shortcut (background from dmg-background.swift). Hidden files sit outside the
# window, so they stay out of sight even when Finder shows hidden files. The
# layout needs Finder automation; without it the DMG still works, in Finder's
# default view.
make_dmg() {
    local app=$1 version=$2 output=$3
    local volume="PCVL $version"
    local staging="$BUILD/dmg" background="$BUILD/dmg-background"
    local writable="$BUILD/writable.dmg" mountpoint="/Volumes/$volume"

    rm -rf "$staging" "$background" "$writable"
    mkdir -p "$staging/.background"
    ditto "$app" "$staging/PCVL.app"
    ln -s /Applications "$staging/Applications"
    swift scripts/dmg-background.swift "$background" $DMG_WIDTH $DMG_HEIGHT \
        $((APP_X + 86)) $((APPLICATIONS_X - 86)) $((ICON_Y + ICON_DROP))
    tiffutil -cathidpicheck "$background/background.png" "$background/background@2x.png" \
        -out "$staging/.background/background.tiff" 2>/dev/null
    [[ -f "$app/Contents/Resources/AppIcon.icns" ]] && cp "$app/Contents/Resources/AppIcon.icns" "$staging/.VolumeIcon.icns"

    [[ -d "$mountpoint" ]] && hdiutil detach "$mountpoint" -quiet -force
    hdiutil create -quiet -volname "$volume" -srcfolder "$staging" -fs HFS+ -format UDRW -ov "$writable"
    hdiutil attach -quiet -readwrite -noverify -noautoopen "$writable"
    # The app's icon for the mounted disk.
    [[ -f "$mountpoint/.VolumeIcon.icns" ]] && command -v SetFile >/dev/null && SetFile -a C "$mountpoint"

    osascript <<EOF >/dev/null 2>&1 || echo "  (Finder layout skipped; allow your terminal to control Finder for the arranged window)"
tell application "Finder"
    tell disk "$volume"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, $((200 + DMG_WIDTH)), $((120 + DMG_HEIGHT))}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.tiff"
        set position of item "PCVL.app" of container window to {$APP_X, $ICON_Y}
        set position of item "Applications" of container window to {$APPLICATIONS_X, $ICON_Y}
        repeat with hiddenName in {".background", ".fseventsd", ".VolumeIcon.icns", ".DS_Store"}
            try
                set position of item hiddenName of container window to {$((DMG_WIDTH / 2)), $((DMG_HEIGHT + 400))}
            end try
        end repeat
        -- No "update" here: it makes Finder delete .VolumeIcon.icns. Closing saves the layout.
        delay 1
        close
    end tell
end tell
EOF

    sync
    hdiutil detach "$mountpoint" -quiet || hdiutil detach "$mountpoint" -quiet -force
    rm -f "$output"
    hdiutil convert -quiet "$writable" -format UDZO -imagekey zlib-level=9 -o "$output"
    rm -rf "$staging" "$background" "$writable"
}

if $DMG_ONLY && [[ -d "$APP" ]]; then
    echo "Reusing $APP"
else
    rm -rf "$BUILD"
    mkdir -p "$BUILD"
    echo "Archiving…"
    xcodebuild -project PCVL.xcodeproj -scheme PCVL -configuration Release -archivePath "$ARCHIVE" archive -quiet
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
ZIP="$BUILD/PCVL-$VERSION.zip"
DMG="$BUILD/PCVL-$VERSION.dmg"

if $DMG_ONLY; then
    echo "Packaging the DMG…"
    make_dmg "$APP" "$VERSION" "$DMG"
    echo "Built $DMG"
    [[ -z "${NO_OPEN:-}" ]] && open "$DMG"
    exit 0
fi

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
