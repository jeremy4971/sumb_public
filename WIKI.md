## Managed Settings with a Configuration Profile
Use the pre-configured .mobileconfig ([MDM version](https://github.com/jeremy4971/sumb_public/blob/main/configuration_profile/SUMB_Settings_Full.mobileconfig) · [Local version](https://github.com/jeremy4971/sumb_public/blob/main/configuration_profile/SUMB_Settings_Light.mobileconfig)), the [JSON manifest for Jamf](https://github.com/jeremy4971/sumb_public/blob/main/jamf_assets/json_manifest/fr.jeremyb.sumb.v2.json) ([documentation](https://developer.jamf.com/jamf-pro/docs/application-custom-settings#jamf-pro)), or manually configure your MDM using the settings below.

### Preference keys
File domain: `fr.jeremyb.sumb`
| Key | Type | Introduced in | Default | Description |
|---|---|---|---|---|
| `hideIconWhenUpToDate` | boolean | v1.0.0 | `false` | Remove the SUMB icon from the menu bar when the Mac is up to date. |
| `hideSettings` | boolean | v2.0.0 | `false` | Hide the Settings menu. Holding Option while right-clicking the menu bar icon still reveals it, as does relaunching SUMB.app. |
| `ignoreAppleUpdateChannel` | boolean | v1.0.3 | `false` | Ignore updates from the standard Apple software update channel; only take managed update declarations (DDM) into account. |
| `menubarDotBlinkingThresholdDays` | integer | v2.0.0 | `2` | Number of days before the update deadline at which the red dot on the menu bar icon starts blinking. `0` turns blinking off. |
| `menubarPrefix` | string | v2.0.0 | *(empty)* | Text placed before the number of days remaining in the menu bar countdown. |
| `menubarPreparingMessage` | string | v2.0.0 | `Preparing update...` | Text shown in the menu bar while the update is being prepared. |
| `menubarSuffix` | string | v2.0.0 | `d` | Text placed after the number of days remaining (e.g. "j" in French, "t" in German). |
| `notificationBody` | string | v2.0.0 | `An update to macOS $VERSION has been scheduled for $DATE.` | Body text of the reminder notification. Supports `$VERSION`, `$DATE` and `$COUNTDOWN` variables. |
| `notificationIntervalMinutes` | integer | v2.0.0 | `120` | Time in minutes between two reminder notifications. (min: 1) |
| `notificationSound` | string | v1.1.1 | *(empty)* | Alert sound, played with the notification and the Scheduler popup. Type only the filename with its extension, not the full path. Leave empty for the system default tone. Only files located in `/System/Library/Sounds` are supported (e.g., `Blow.aiff` `Sosumi.aiff` `Morse.aiff`). |
| `notificationThresholdDays` | integer | v2.0.0 | `4` | Days remaining before the update deadline at which SUMB starts sending reminder notifications. (min: 0) |
| `notificationTitle` | string | v2.0.0 | `Managed Update` | Title displayed in the reminder notification. Supports `$VERSION`, `$DATE` and `$COUNTDOWN` variables. |
| `notificationsEnabled` | boolean | v1.0.0 | `false` | Allow SUMB to post reminder notifications about the scheduled macOS update. |
| `popoverFooter` | string | v2.0.0 | *(empty)*| Warning at the bottom of the popover. Supports Markdown links: `[text](https://example.com)` |
| `popoverTitle` | string | v2.0.0 | `macOS Update` | Title shown at the top of the popover. |
| `popoverUpToDateMessage` | string | v2.0.0 | `Your Mac is up to date.` | Message displayed in the popover when the Mac is up to date. |
| `popoverUpdateButton` | string | v2.0.0 | `Open Software Update` | Label of the button that takes the user to Software Update. |
| `popupBody` | string | v2.0.0 | `An update to macOS $VERSION has been scheduled for $DATE.` | Message of the Scheduler popup. Supports `$VERSION`, `$DATE` and `$COUNTDOWN` variables. |
| `popupCal1MondayHours` | string | v2.0.0 | `12,17` | Hours suggested on Monday, comma-separated from 0 to 23. `12,17` suggests 12h00 and 17h00. |
| `popupCal2TuesdayHours` | string | v2.0.0 | `12,17` | Hours suggested on Tuesday, comma-separated from 0 to 23. `12,17` suggests 12h00 and 17h00. |
| `popupCal3WednesdayHours` | string | v2.0.0 | `12,17` | Hours suggested on Wednesday, comma-separated from 0 to 23. `12,17` suggests 12h00 and 17h00. |
| `popupCal4ThursdayHours` | string | v2.0.0 | `12,17` | Hours suggested on Thursday, comma-separated from 0 to 23. `12,17` suggests 12h00 and 17h00. |
| `popupCal5FridayHours` | string | v2.0.0 | `12,17` | Hours suggested on Friday, comma-separated from 0 to 23. `12,17` suggests 12h00 and 17h00. |
| `popupCal6SaturdayHours` | string | v2.0.0 | *(empty)* | Hours suggested on Saturday, comma-separated from 0 to 23. |
| `popupCal7SundayHours` | string | v2.0.0 | *(empty)* | Hours suggested on Sunday, comma-separated from 0 to 23. |
| `popupEnabled` | boolean | v2.0.0 | `false` | Show the popup reminder at the start of each allowed hour. |
| `popupRescheduleButton` | string | v2.0.0 | `Remind Me` | Label of button that opens the Scheduler window. |
| `popupSchedulerHelp` | string | v2.0.0 | `Please select the times you are available to update your Mac.`<br>`You will get one popup reminder per selected hour.` | Instructions shown above the grid in the Scheduler window. |
| `popupThresholdDays` | integer | v2.0.0 | `2` | Days remaining before the update deadline at which the Scheduler popup starts showing. |
| `popupTitle` | string | v2.0.0 | `macOS Update` | Title of the popup reminder. |
| `popupUpdateButton` | string | v2.0.0 | `Update Now` | Label of the popup update button, opens Software Update. |
| `showDockIcon` | boolean | v1.4.0 | `false` | Show the SUMB icon in the Dock when an update is available. |


### Configuration Profile
File domain : `fr.jeremyb.sumb`

![Jamf Custom Settings](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/custom_settings.png)

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>hideIconWhenUpToDate</key>
	<false/>
	<key>hideSettings</key>
	<false/>
	<key>ignoreAppleUpdateChannel</key>
	<false/>
	<key>menubarDotBlinkingThresholdDays</key>
	<integer>2</integer>
	<key>menubarPrefix</key>
	<string></string>
	<key>menubarPreparingMessage</key>
	<string>Preparing update...</string>
	<key>menubarSuffix</key>
	<string>d</string>
	<key>notificationBody</key>
	<string>An update to macOS $VERSION has been scheduled for $DATE.</string>
	<key>notificationIntervalMinutes</key>
	<integer>120</integer>
	<key>notificationSound</key>
	<string></string>
	<key>notificationThresholdDays</key>
	<integer>4</integer>
	<key>notificationTitle</key>
	<string>Managed Update</string>
	<key>notificationsEnabled</key>
	<false/>
	<key>popoverFooter</key>
	<string></string>
	<key>popoverTitle</key>
	<string>macOS Update</string>
	<key>popoverUpToDateMessage</key>
	<string>Your Mac is up to date.</string>
	<key>popoverUpdateButton</key>
	<string>Open Software Update</string>
	<key>popupBody</key>
	<string>An update to macOS $VERSION has been scheduled for $DATE.</string>
	<key>popupCal1MondayHours</key>
	<string>12,17</string>
	<key>popupCal2TuesdayHours</key>
	<string>12,17</string>
	<key>popupCal3WednesdayHours</key>
	<string>12,17</string>
	<key>popupCal4ThursdayHours</key>
	<string>12,17</string>
	<key>popupCal5FridayHours</key>
	<string>12,17</string>
	<key>popupCal6SaturdayHours</key>
	<string></string>
	<key>popupCal7SundayHours</key>
	<string></string>
	<key>popupEnabled</key>
	<false/>
	<key>popupRescheduleButton</key>
	<string>Remind Me</string>
	<key>popupSchedulerHelp</key>
	<string>Please select the times you are available to update your Mac.
You will get one popup reminder per selected hour.</string>
	<key>popupThresholdDays</key>
	<integer>2</integer>
	<key>popupTitle</key>
	<string>macOS Update</string>
	<key>popupUpdateButton</key>
	<string>Update Now</string>
	<key>showDockIcon</key>
	<false/>
</dict>
</plist>
```

### Popup Scheduler
SUMB can ask users to update their macOS during hours they choose. The weekly grid runs Monday to Sunday with one box per hour. Drag over boxes to select them: green for suggested hours in Settings, blue in the user's Scheduler window.

<img width="500" alt="image" src="https://github.com/user-attachments/assets/2c509fdb-6c60-4313-b28f-b44b1d7e0a36" />

**Suggested schedule:**
Set it with a profile, which locks the grid, using the keys `popupCal1MondayHours` to `popupCal7SundayHours`. Each key lists hours separated by commas: `9,10,11,14,15` suggests 09h00>11h59h and 14h00>15h59.

**User schedule:**
Users open the Scheduler window in two ways: inside the popup when it appears, or the calendar button in the menu bar popover.
Their schedule replaces the suggested one. Closing the window with nothing selected restores the suggested schedule. Customize the text above the grid with `popupSchedulerHelp`.

**Popups:** They appear only when a managed update has a DDM deadline not yet passed. They show at the start of each allowed hour, centered on every screen, and in front of all windows.

<img width="500" alt="image" src="https://github.com/user-attachments/assets/d7db7b60-e1d1-42fb-8c20-c02405b40952" />

**Notes:** Popups currently don't honor Focus Mode. However, they wait during virtual meetings (mic or camera in use), and full screen QuickTime, VLC, IINA, Keynote, PowerPoint or Canva presentations. Edge case : Google Slides outside of a virtual meeting is not supported.

### Managed Notification
<img width="382" height="101" alt="notification-tcc" src="https://github.com/user-attachments/assets/80d5a4d4-5b69-44c1-86f8-f7708aa159d7" />

To suppress this prompt and programmatically allow SUMB's notifications, you need to manage the bundle ID `fr.jeremyb.sumb` in your MDM. I recommend setting the alert banner type to **Persistent** to ensure end users do not miss the reminders.

<img width="800" alt="Jamf Managed Notification" src="https://github.com/jeremy4971/sumb_public/blob/main/screenshots/managed_notification.png" />

### Managed Login Item (LaunchAgent)
<img width="300" alt="login-item" src="https://github.com/user-attachments/assets/d8d721bb-36fe-4316-8a87-f66c2d6a7444" />

To suppress this dialog, allow Team ID `73MS2PM6D7` in your MDM. This will prevent users from disabling the LaunchAgent.

![Jamf Login Items](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/managed_login_item.png)

### Hide notch
Experimental. When the menu bar is full, SUMB can get hidden behind the notch. Run the following command to reduce your display resolution and restore the entire menu bar. There is intentionally no managed key for this setting.

    # Hide notch
    /Applications/SUMB.app/Contents/MacOS/SUMB -nonotch
    
    # Show notch
    /Applications/SUMB.app/Contents/MacOS/SUMB -notch

## Jamf Assets

### Extension Attribute

* [Enforced macOS version and date](https://github.com/jeremy4971/sumb_public/blob/main/jamf_assets/extension_attribute/scheduled_version_date.sh)
* [User's schedule for popup reminders](https://github.com/jeremy4971/sumb_public/blob/main/jamf_assets/extension_attribute/user_scheduler.sh)

### Patch Definition

Access the SUMB patch definition for Jamf Software Title Editor / Patch Management [here](https://github.com/jeremy4971/sumb_public/blob/main/jamf_assets/software_title_editor/SUMB.json). You can also add my custom patch source to your Jamf Pro server. Please note that this is still experimental. Read the [How-to guide](https://learn.jamf.com/r/en-US/jamf-pro-documentation-11.31.0/Adding_a_Patch_External_Source_to_Jamf_Pro?content-lang=en-US) for setup instructions.

* Host: `patch.jeremyb.fr`
* Port: `443`
* SSL: `Yes`

## Declarative Device Management (DDM)

### Jamf
Schedule a DDM update in the Blueprints menu
![Blueprint](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/jamf-blueprint3.png)

### SimpleMDM
Create a Managed Software Update profile
![DDM update on SimpleMDM](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/simplemdm_ddm.png)

## Miscellaneous

### Reset user's reminder schedule

```
#!/bin/zsh
# Revert user's reminder schedule to the suggested schedule.

CURRENT_USER=$(stat -f %Su /dev/console)
defaults delete "/Users/$CURRENT_USER/Library/Preferences/fr.jeremyb.sumb.plist" schedulerHours
killall -9 "SUMB"

```

### Uninstall SUMB
Use the [payload-free uninstaller package](https://github.com/jeremy4971/sumb_public/releases/download/v1.3.0/SUMBUninstaller-1.0.0.pkg) or the script below.

```
#!/bin/zsh

# Read current user
CURRENT_USER=$(/usr/bin/stat -f %Su /dev/console)
USER_ID=$(/usr/bin/id -u "$CURRENT_USER")

# Unload LaunchAgent
/bin/launchctl bootout gui/$USER_ID /Library/LaunchAgents/fr.jeremyb.sumb.plist

# Kill SUMB if still running
if /usr/bin/pgrep -x "SUMB"; then
	/usr/bin/killall -9 "SUMB"
fi

# Remove files
/bin/rm -rf "/Applications/SUMB.app"
/bin/rm -f "/Library/LaunchAgents/fr.jeremyb.sumb.plist"
/bin/rm -f "/Users/$CURRENT_USER/Library/Preferences/fr.jeremyb.sumb.plist"
/usr/sbin/pkgutil --forget "fr.jeremyb.sumb"

# Reload preferences
/usr/bin/killall cfprefsd
```

### Troubleshooting
Holding Option and right-clicking the menu bar icon reveals the two update .plist files that SUMB uses to determine the deadline and target OS version.

<img width="400" alt="image" src="https://github.com/user-attachments/assets/967eb48c-28c0-4a5a-869c-320f6934570e" />

### Frequently Asked Questions
Find answers to common questions about the app in the [FAQ](https://github.com/jeremy4971/sumb_public/wiki/Frequently-Asked-Questions).