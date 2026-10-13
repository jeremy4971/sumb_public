#!/bin/bash

# Hours when SUMB can show the update popup to the logged in user, Monday first.
# The user's own Scheduler grid if set, otherwise the suggested hours.

DOMAIN="fr.jeremyb.sumb"
DAYS=(Mon Tue Wed Thu Fri Sat Sun)
CAL_KEYS=(popupCal1MondayHours popupCal2TuesdayHours popupCal3WednesdayHours
    popupCal4ThursdayHours popupCal5FridayHours popupCal6SaturdayHours popupCal7SundayHours)

user=$(/usr/bin/stat -f%Su /dev/console)
if [[ -z "$user" || "$user" == "root" || "$user" == "loginwindow" ]]; then
    echo "<result>No user logged in</result>"
    exit 0
fi
uid=$(/usr/bin/id -u "$user")
home=$(/usr/bin/dscl . -read "/Users/$user" NFSHomeDirectory | /usr/bin/awk '{print $2}')

# Managed values win, like in the app. Fails when the key isn't set anywhere.
read_pref() {
    local plist
    for plist in "/Library/Managed Preferences/$user/$DOMAIN" "/Library/Managed Preferences/$DOMAIN"; do
        if [[ -f "$plist.plist" ]] && /usr/bin/defaults read "$plist" "$1" 2>/dev/null; then
            return 0
        fi
    done
    # Plist path
    plist="$home/Library/Preferences/$DOMAIN.plist"
    if [[ $EUID -eq 0 ]]; then
        /bin/launchctl asuser "$uid" /usr/bin/sudo -u "$user" /usr/bin/defaults read "$plist" "$1" 2>/dev/null
    else
        /usr/bin/defaults read "$plist" "$1" 2>/dev/null
    fi
}

# "12, 17" -> bitmask. Anything that isn't an hour from 0 to 23 is skipped.
string_to_mask() {
    local mask=0 part parts
    IFS=',' read -ra parts <<< "$1"
    for part in "${parts[@]}"; do
        part="${part//[[:space:]]/}"
        if [[ "$part" =~ ^[0-9]+$ ]] && (( 10#$part < 24 )); then
            (( mask |= 1 << 10#$part ))
        fi
    done
    echo "$mask"
}

mask_to_hours() {
    local hours=() h
    for (( h = 0; h < 24; h++ )); do
        (( ($1 >> h) & 1 )) && hours+=("$h")
    done
    local IFS=','
    echo "${hours[*]}"
}

# The user's grid is 7 masks. The app ignores it otherwise.
masks=()
if stored=$(read_pref schedulerHours); then
    read -ra masks <<< "$(echo "$stored" | /usr/bin/tr -cs '0-9' ' ')"
fi

if (( ${#masks[@]} != 7 )); then
    masks=()
    for i in "${!CAL_KEYS[@]}"; do
        if ! value=$(read_pref "${CAL_KEYS[$i]}"); then
            # Same default as the app: noon and 5 pm on weekdays.
            value=""
            (( i < 5 )) && value="12,17"
        fi
        masks+=("$(string_to_mask "$value")")
    done
fi

result=""
for i in "${!DAYS[@]}"; do
    result+="${DAYS[$i]}:$(mask_to_hours "${masks[$i]}")"
    (( i < 6 )) && result+=$'\n'
done

echo "<result>$result</result>"

exit 0
