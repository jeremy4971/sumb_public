## Managed Settings with a Configuration Profile
Use the pre-configured .mobileconfig ([MDM version](https://github.com/jeremy4971/sumb_public/blob/main/configuration_profile/SUMB_Settings_Full.mobileconfig) · [Local version](https://github.com/jeremy4971/sumb_public/blob/main/configuration_profile/SUMB_Settings_Light.mobileconfig)), the [JSON manifest for Jamf](https://github.com/jeremy4971/sumb_public/blob/main/jamf_assets/json_manifest/fr.jeremyb.sumb.json) ([documentation](https://developer.jamf.com/jamf-pro/docs/application-custom-settings#jamf-pro)), or manually configure your MDM using the settings below.

### Preference keys
File domain : `fr.jeremyb.sumb`
| Key | Type | Default | Description |
|---|---|---|---|
| `hideIconWhenUpToDate` | boolean | `false` | Remove the SUMB icon from the menu bar when the Mac is up to date. |
| `disableContextMenuActions` | boolean | `false` | Hide the Settings menu. Holding Option while right-clicking still reveals it, as does relaunching SUMB.app. |
| `ignoreAppleUpdateChannel` | boolean | `false` | Ignore updates from the standard Apple software update channel; only take managed update declarations (DDM) into account. |
| `notificationsEnabled` | boolean | `true` | Allow SUMB to post reminder notifications about the scheduled macOS update. |
| `notificationSound` | string | *(empty)* | Sound played with the notification. Leave empty for the system default tone. Only files located in `/System/Library/Sounds` are supported (e.g., `Blow.aiff`, `Sosumi.aiff`, `Morse.aiff`). |
| `dotBlinkingDays` | integer | `0` | Number of days before the update deadline at which the red dot on the menu bar icon starts blinking. `0` turns blinking off. |
| `reminderThresholdDays` | integer | `2` | Days remaining before the update deadline at which SUMB starts sending reminder notifications. (min: 0) |
| `reminderIntervalMinutes` | integer | `120` | Time in minutes between two reminder notifications. (min: 1) |
| `reminderNotificationTitle` | string | `Managed Update` | Title displayed in the reminder notification. |
| `reminderNotificationBody` | string | `An update to macOS $VERSION has been scheduled for $DATE.` | Body text of the reminder notification. Supports `$VERSION` and `$DATE` variables. |
| `localizedPopoverTitle` | string | `macOS Update` | Title shown at the top of the popover displayed when the user clicks the menu bar icon. |
| `localizedRestartWarning` | string | `Be aware that your Mac will automatically restart after the deadline. [Learn more...](https://support.apple.com/en-us/100100)` | Warning at the bottom of the popover. Supports Markdown links. |
| `localizedUpdateNowButton` | string | `Open Software Update` | Label of the button that takes the user to Software Update. |
| `localizedUpToDateMessage` | string | `Your Mac is up to date.` | Message displayed in the popover when the Mac is up to date. |
| `localizedUpdatingMenuBar` | string | `Preparing update...` | Text shown in the menu bar while the update is being prepared. |
| `localizedDayPrefix` | string | *(empty)* | Text placed before the number of days remaining in the menu bar countdown. |
| `localizedDaySuffix` | string | `d` | Suffix appended to the number of days remaining (e.g. "j" in French, "t" in German). |


### Application & Custom Settings
File domain : `fr.jeremyb.sumb`

![Jamf Custom Settings](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/custom_settings.png)

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>disableContextMenuActions</key>
	<false/>
	<key>dotBlinkingDays</key>
	<integer>0</integer>
	<key>hideIconWhenUpToDate</key>
	<false/>
	<key>ignoreAppleUpdateChannel</key>
	<false/>
	<key>localizedDayPrefix</key>
	<string></string>
	<key>localizedDaySuffix</key>
	<string>d</string>
	<key>localizedPopoverTitle</key>
	<string>macOS Update</string>
	<key>localizedRestartWarning</key>
	<string>Be aware that your Mac will automatically restart after the deadline. [Learn more...](https://support.apple.com/en-us/100100)</string>
	<key>localizedUpToDateMessage</key>
	<string>Your Mac is up to date.</string>
	<key>localizedUpdateNowButton</key>
	<string>Open Software Update</string>
	<key>localizedUpdatingMenuBar</key>
	<string>Preparing update...</string>
	<key>notificationSound</key>
	<string></string>
	<key>notificationsEnabled</key>
	<true/>
	<key>reminderIntervalMinutes</key>
	<integer>120</integer>
	<key>reminderNotificationBody</key>
	<string>An update to macOS $VERSION has been scheduled for $DATE.</string>
	<key>reminderNotificationTitle</key>
	<string>Managed Update</string>
	<key>reminderThresholdDays</key>
	<integer>2</integer>
</dict>
</plist>
```

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

### Extension Attribute for Jamf

In Jamf, use this [Extension Attribute](https://github.com/jeremy4971/sumb_public/blob/main/jamf_assets/extension_attribute/scheduled_version_date.sh) to display a computer's update deadline.

### Patch Definition for Jamf
You can find a patch definition [here](https://github.com/jeremy4971/sumb_public/blob/main/jamf_assets/software_title_editor/sumb_github_releases.json) for [Jamf Software Title Editor](https://learn.jamf.com/r/en-US/title-editor/Title_Editor_Documentation) / [Jamf Pro Patch Management](https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/PatchManagement).

### Declarative Device Management (DDM)

#### Jamf
Schedule a DDM update in the Blueprints menu
![Blueprint](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/jamf-blueprint3.png)

#### SimpleMDM
Create a Managed Software Update profile
![DDM update on SimpleMDM](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/simplemdm_ddm.png)

### Troubleshooting
Holding Option and right-clicking the menu bar icon reveals the two update .plist files that SUMB uses to determine the deadline and target OS version.

<img width="400" alt="image" src="https://github.com/user-attachments/assets/967eb48c-28c0-4a5a-869c-320f6934570e" />

### Frequently Asked Questions
Find answers to common questions about the app in the [FAQ](https://github.com/jeremy4971/sumb_public/wiki/Frequently-Asked-Questions).