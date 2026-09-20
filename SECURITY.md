## Security practices


* Hardened Runtime is enabled.
* There are zero third-party dependencies.
* The .pkg and the .app are notarized by Apple and signed with the following developer ID : `73MS2PM6D7`
* The source code is scanned with Semgrep and Claude Fable to detect vulnerabilities and bad security patterns.

If you discover a security vulnerability in this project, please report it privately to **security |at| jeremyb |dot| fr**. You should receive an acknowledgment within 48 hours.


## Security disclaimer

SUMB reads these system files and sounds folder :
* `/private/var/db/softwareupdate/SoftwareUpdateDDMStatePersistence.plist`
* `/Library/Preferences/com.apple.SoftwareUpdate.plist`
* `/System/Library/Sounds/`


SUMB installer requires admin privileges to : 
* Install the app in `/Applications/`
* Install the LaunchAgent in `/Library/LaunchAgents/` needed to keep the app alive, even if the end-user tries to close it.

In addition, SUMB : 
* Does not run privileged commands.
* Does not ask for an online account.
* Does not display ads.
* Does not collect or send any data.
* Does not phone home.
* Does not have a built-in auto-updater.
* Does not require any PPPC permissions.
* Does not display a donation button.
* Does not display a link to a personal website.
* Contains AI-generated code.
