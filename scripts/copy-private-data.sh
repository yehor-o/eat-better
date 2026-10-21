#!/bin/sh
# Xcode build phase: copies the owner's private data into the app bundle.
# Private/ is git-ignored, so nothing personal ever reaches the repository.
# Without these files the app falls back to the demo recipes in EatBetterCore.
set -eu

DEST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
mkdir -p "$DEST"

for name in recipes ingredients; do
    src="${SRCROOT}/Private/${name}.json"
    if [ -f "$src" ]; then
        cp "$src" "$DEST/private-${name}.json"
        echo "Bundled private ${name}.json"
    else
        rm -f "$DEST/private-${name}.json"
    fi
done
