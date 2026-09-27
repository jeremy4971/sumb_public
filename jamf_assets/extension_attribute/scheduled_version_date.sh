#!/bin/bash

PLIST="/var/db/softwareupdate/SoftwareUpdateDDMStatePersistence.plist"

# Check the plist exists
if [[ ! -f "$PLIST" ]]; then
    echo "<result>No DDM enforcement</result>"
    exit 0
fi

# Convert to XML so we can parse it
xml=$(/usr/bin/plutil -convert xml1 -o - "$PLIST" 2>/dev/null)

targetOS=$(echo "$xml" | /usr/bin/grep -A1 '<key>TargetOSVersion</key>' \
    | /usr/bin/awk -F'[<>]' '/<string>/ {print $3; exit}')

targetDate=$(echo "$xml" | /usr/bin/grep -A1 '<key>TargetLocalDateTime</key>' \
    | /usr/bin/awk -F'[<>]' '/<string>/ {print $3; exit}')

if [[ -n "$targetOS" && -n "$targetDate" ]]; then
    echo "<result>${targetOS} @ ${targetDate}</result>"
else
    echo "<result>No DDM enforcement</result>"
fi

exit 0
