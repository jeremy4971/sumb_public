![sumb-banner](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/sumb_banner2.jpg)

## SUMB · Software Update Menu Bar
[![Github](https://img.shields.io/badge/status-maintained-978A89)](https://github.com/jeremy4971/sumb_public/releases) [![Github](https://img.shields.io/badge/mdm-fully%20customizable-A79C9B)](https://github.com/jeremy4971/sumb_public/wiki) [![Github](https://img.shields.io/badge/privacy-%20no%20telemetry-758498)](https://github.com/jeremy4971/sumb_public?tab=security-ov-file#security-policy) [![Github](https://img.shields.io/badge/security-signed%20%20%C2%B7%20notazired-8796A8)](https://github.com/jeremy4971/sumb_public?tab=security-ov-file#security-policy) [![Github](https://img.shields.io/badge/semgrep-passing-5E707F)](https://semgrep.dev/)


SUMB is a companion app for scheduled macOS updates via Declarative Device Management (DDM). Featuring a live menu bar countdown, it gives end users continuous, subtle visibility so they can plan their reboot on their own terms, avoiding abrupt disruptions during critical tasks or meetings.

[<img src="https://github.com/jeremy4971/sumb_public/blob/main/screenshots/github-download-button-white.png" width="250" height="81">](https://github.com/jeremy4971/sumb_public/releases) [<img src="https://github.com/jeremy4971/sumb_public/blob/main/screenshots/github-macadmins-button-white.png" width="250" height="81">](https://macadmins.slack.com/archives/C05JSCXQQ5T) 


## Screenshots

<img src="https://github.com/jeremy4971/sumb_public/blob/main/screenshots/home1.png" width="646" alt="5 days left">

<img src="https://github.com/jeremy4971/sumb_public/blob/main/screenshots/home2.png" width="646" alt="Custom notification">

<img src="https://github.com/jeremy4971/sumb_public/blob/main/screenshots/home3.png" width="646" alt="Up to date">

![General option](https://github.com/jeremy4971/sumb_public/blob/main/screenshots/settings-x2.png)


## Quick start


### Install script
    curl -fsSL https://raw.githubusercontent.com/jeremy4971/sumb_public/52e75c8b33da84c566f67939dda25e87ea58466f/install.sh | bash


### Manual download
[Download](https://github.com/jeremy4971/sumb_public/releases) and install the .pkg, no configuration needed. Once a scheduled DDM update is deployed from your MDM, the menu bar icon will display the time remaining.
> Requires macOS 15.0 or later.


## Documentation
To learn more about SUMB features, make sure to take a look at the [wiki](https://github.com/jeremy4971/sumb_public/wiki).

* [Managed Configuration](https://github.com/jeremy4971/sumb_public/wiki#managed-settings-with-a-configuration-profile)
* [Uninstall Script](https://github.com/jeremy4971/sumb_public/wiki#uninstall-sumb)
* [Frequently Asked Questions](https://github.com/jeremy4971/sumb_public/wiki/Frequently-Asked-Questions)


## Similar projects
If you are looking for similar tools, here are several other projects worth checking out :

* [Nudge](https://github.com/macadmins/nudge) : The original gangster. Built in Swift.
* [Super](https://github.com/Macjutsu/super) : Pop-up reminders via IBM Notifier.
* [DDM OS Reminder](https://github.com/dan-snelson/DDM-OS-Reminder) : Pop-up reminders via swiftDialog.
* [SupportApp](https://github.com/root3nl/supportapp) : macOS menu bar app for organizations.
