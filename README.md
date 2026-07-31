
## SUMB (Software Update Menu Bar)

SUMB is a native Swift companion app for scheduled macOS updates via Declarative Device Management (DDM). By utilizing a live menu bar countdown, it leverages cognitive design, giving users a constant, subtle psychological buffer so they can plan their reboot on their own terms, rather than getting slapped with an aggressive popup while in a flow state or mid-meeting.

Join [#sumb](https://macadmins.slack.com/archives/C05JSCXQQ5T) on [MacAdmins](https://www.macadmins.org/) for news and share your feedback!

✅ Easy-to-set-up. ✅ Apple inspired UI. ✅ Texts customization. ✅ No ads or telemetry.

## Screenshots

![5 days left](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/popover-update.png?raw=true)

  

![Custom notification](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/custom-notification-3.png?raw=true)

  

![Past deadline](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/popover-past-deadline.png?raw=true)

  

![Up to date](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/popover-uptodate.png?raw=true)

  

![General option](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/option-general3.png?raw=true)

  

![Localization options](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/option-localization2.png?raw=true)

## Quick start

Just install the .pkg, no configuration needed. Once a scheduled DDM update is deployed from your MDM, the menu bar icon will display the time remaining.

> Requires macOS 15.0 or later.

## Managed Settings with a Configuration Profile
Use this pre-configured [.mobileconfig](https://github.com/jeremy4971/sumb_public/blob/main/configuration_profile/SUMB_Settings.mobileconfig) or manually configure your MDM using the settings below.

### Application & Custom Settings : fr.jeremyb.sumb

![Jamf Custom Settings](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/custom_settings.png?raw=true)

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>disableContextMenuActions</key>
	<false/>
	<key>hideIconWhenUpToDate</key>
	<false/>
	<key>localizedDaySuffix</key>
	<string>d</string>
	<key>localizedPopoverTitle</key>
	<string>macOS Update</string>
	<key>localizedRestartWarning</key>
	<string>Be aware that your Mac will automatically restart after the deadline.</string>
	<key>localizedUpToDateMessage</key>
	<string>Your Mac is up to date.</string>
	<key>localizedUpdateNowButton</key>
	<string>Open Software Update</string>
	<key>localizedUpdatingMenuBar</key>
	<string>Preparing update...</string>
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

### Managed Notification : fr.jeremyb.sumb

![Jamf Managed Notification](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/managed_notification.png?raw=true)

  

### Managed Login Item (LaunchAgent) : Team ID 73MS2PM6D7

![Jamf Login Items](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/managed_login_item.png?raw=true)

### Hide notch (experimental)
When the menu bar is full, SUMB can get hidden behind the notch. Run the following command to reduce your display resolution and restore the entire menu bar. There is intentionally no managed key for this setting.

    # Hide notch
    /Applications/SUMB.app/Contents/MacOS/SUMB -nonotch
    
    # Show notch
    /Applications/SUMB.app/Contents/MacOS/SUMB -notch


### Uninstall SUMB

    # Read current user
    CURRENT_USER=$(stat -f %Su /dev/console)
    USER_ID=$(id -u "$CURRENT_USER")
    
    # Unload LaunchAgent
    sudo launchctl bootout gui/$USER_ID /Library/LaunchAgents/fr.jeremyb.sumb.plist
    
    # Remove files
    sudo rm -rf "/Applications/SUMB.app"
    sudo rm -f "/Library/LaunchAgents/fr.jeremyb.sumb.plist"
    sudo rm -f "/Users/$CURRENT_USER/Library/Preferences/fr.jeremyb.sumb.plist"
    sudo pkgutil --forget "fr.jeremyb.sumb"

### Extension Attribute

In Jamf, use this [Extension Attribute](https://github.com/jeremy4971/sumb_public/blob/main/extension_attribute_jamf/scheduled-version-date.sh) to display a computer's update deadline.

### With Jamf, schedule a DDM update in the Blueprints menu

![Blueprint](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/jamf-blueprint3.png?raw=true)

### On SimpleMDM, create a Managed Software Update profile
![DDM update on SimpleMDM](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/simplemdm_ddm.png?raw=true)

### Disclaimer

This software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and noninfringement. Please note that parts of this codebase contain AI-generated code.

In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.
