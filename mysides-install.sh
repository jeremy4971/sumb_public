#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

REPO="jeremy4971/mysides-swift"

echo "Fetching the latest release info for $REPO..."

# Query the GitHub API for releases, and extract the browser_download_url for the .pkg file
# We use the general /releases endpoint rather than /releases/latest in case the target is marked as a "pre-release"
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$REPO/releases" | \
    grep -Eo '"browser_download_url": *"[^"]+mysides-[^"]*\.pkg"' | \
    head -n 1 | \
    awk -F'"' '{print $4}')

if [ -z "$DOWNLOAD_URL" ]; then
  echo "Error: Could not find a .pkg file in the recent releases."
  echo "Please check the repository or your internet connection."
  exit 1
fi

echo "Found latest release: $DOWNLOAD_URL"

# Create a temporary directory for the download
TMP_DIR=$(mktemp -d)
PKG_NAME=$(basename "$DOWNLOAD_URL")
PKG_PATH="$TMP_DIR/$PKG_NAME"

echo "⏳ Downloading $PKG_NAME..."
# Using curl with -L to follow redirects (GitHub always redirects asset downloads) and -# for a progress bar
curl -L -o "$PKG_PATH" "$DOWNLOAD_URL"

echo "Installing $PKG_NAME..."
# The macOS installer command requires root privileges
sudo installer -pkg "$PKG_PATH" -target /

echo "Cleaning up..."
rm -rf "$TMP_DIR"

echo "mysides has been successfully updated/installed!"
