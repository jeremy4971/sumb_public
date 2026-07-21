## SUMB (Scheduled Update Menu Bar)
If you're tired of traditional update tools like Nudge or SUPERMAN having a horrible UI and getting right in the user's face, SUMB takes a much more user-first approach.

It’s a native Swift companion app for scheduled macOS updates via blueprints. Instead of interrupting workflows with aggressive pop-ups, it lives discreetly in the menu bar with a live countdown. It also features optional notification reminders that actually respect the user's Focus mode. Basically, it keeps users informed without ruining their UX.

✅ Free.  ✅ Apple inspired UI.  ✅ Texts customization.  ✅ Signed and notarized.  

## Screenshots
![5 days left](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/popover-update.png?raw=true)

![Custom notification](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/custom-notification-2.png?raw=true)

![Past deadline](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/popover-past-deadline.png?raw=true)

![Up to date](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/popover-uptodate.png?raw=true)

![General option](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/option-general2.png?raw=true)

![Localization options](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/option-localization2.png?raw=true)
## Basic use
Install the .pkg and that's it, no configuration needed. Once an update blueprint is deployed, the menubar will display the time remaining.

## Advanced use

### Configuration Profile : fr.jeremyb.sumb

    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    	<key>disableContextMenuActions</key>
    	<false/>
    	<key>localizedDaySuffix</key>
    	<string>d</string>
    	<key>localizedPopoverTitle</key>
    	<string>macOS Update</string>
    	<key>localizedRestartWarning</key>
    	<string>Your device will restart and update once the deadline passes.</string>
    	<key>localizedUpToDateMessage</key>
    	<string>Your Mac is up to date.</string>
    	<key>localizedUpdateNowButton</key>
    	<string>Update Now</string>
    	<key>localizedUpdatingMenuBar</key>
    	<string>Preparing update...</string>
    	<key>notificationsEnabled</key>
    	<false/>
    	<key>reminderNotificationBody</key>
    	<string>An update to macOS $VERSION has been scheduled for $DATE.</string>
    	<key>reminderNotificationTitle</key>
    	<string>Managed Update</string>
    	<key>reminderThresholdDays</key>
    	<integer>4</integer>
    </dict>
    </plist>

### Managed Notification
![Jamf Managed Notification](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/managed-notification.png?raw=true)

### Managed LaunchAgent
Soon.
