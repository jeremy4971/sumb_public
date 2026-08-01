## Security policy

SUMB installer requires admin privileges to : 
* Install the app in /Applications/
* Install the LaunchAgent in /Library/LaunchAgents/ (needed to keep the app alive, even if the end-user tries to close it).

SUMB constantly reads these two local files :
* `/var/db/softwareupdate/SoftwareUpdateDDMStatePersistence.plist`
* `/Library/Preferences/com.apple.SoftwareUpdate.plist`

In addition, SUMB : 
* Does NOT run root commands.
* Does NOT ask for an online account.
* Does NOT require Internet access.
* Does NOT display ads.
* Does NOT run telemetry.
* Does NOT phone home.
* Does NOT have a built-in auto-updater.
* Does NOT trigger any PPPC prompts : personal files, full disk access, accessibility, screen recording, input monitoring, etc.
* Does NOT display a donation button.
* Does NOT display a link to a personal website.
* Contains AI-generated code.

## Security practices

* The .pkg and the .app are always signed and notarized by Apple with the following developer ID : 73MS2PM6D7.
* The source code is constantly scanned with Semgrep for vulnerabilities and bad security patterns.

If you discover a security vulnerability in this project, please report it privately to **security |at| jeremyb |dot| fr**. You should receive an acknowledgment within 48 hours.
