#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

REPO="jeremy4971/sumb_public"
TEAM_ID="73MS2PM6D7"

echo "Fetching the latest release info for $REPO..."

# Query the GitHub API for releases, and extract the browser_download_url for the .pkg file
# Use the general /releases endpoint rather than /releases/latest in case the target is marked as a "pre-release"
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$REPO/releases" | \
    grep -Eo '"browser_download_url": *"[^"]+SUMB-[^"]*\.pkg"' | \
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
trap 'rm -rf "$TMP_DIR"' EXIT # Clean up even if we bail out early
PKG_NAME=$(basename "$DOWNLOAD_URL")
PKG_PATH="$TMP_DIR/$PKG_NAME"

echo "Downloading $PKG_NAME..."
curl -L -o "$PKG_PATH" "$DOWNLOAD_URL"

echo "Verifying the signature of $PKG_NAME..."

# pkgutil exits non-zero if the package is unsigned or the signature is broken
if ! SIGNATURE=$(pkgutil --check-signature "$PKG_PATH" 2>&1); then
  echo "Error: $PKG_NAME is not signed, or its signature could not be read."
  echo "$SIGNATURE"
  exit 1
fi

# Check if the signature is the correct one
if ! echo "$SIGNATURE" | grep -q "Developer ID Installer:.*($TEAM_ID)"; then
  echo "Error: $PKG_NAME is not signed by the expected Developer ID ($TEAM_ID)."
  echo "Aborting install."
  echo "$SIGNATURE"
  exit 1
fi

echo "Signature OK: signed by Developer ID $TEAM_ID"

echo "Installing $PKG_NAME..."
sudo installer -pkg "$PKG_PATH" -target /

echo "SUMB has been successfully installed!"