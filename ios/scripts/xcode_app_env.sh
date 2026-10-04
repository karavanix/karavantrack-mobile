#!/bin/sh
# One-time setup before building or archiving from Xcode.app.
#
# permission_handler_apple's Package.swift is evaluated by SwiftPM with no
# Xcode build settings, so an .xcconfig cannot reach it; it reads environment
# variables only. Xcode.app gets its environment from launchd, hence launchctl.
# The setting is lost on reboot: run this again after restarting the Mac.
#
# Command-line builds (`flutter build ios`, CI) find the plist on their own and
# do not need this.

set -e

plist="$(cd "$(dirname "$0")/.." && pwd)/Runner/Info.plist"
launchctl setenv PERMISSION_HANDLER_INFO_PLIST "${plist}"
echo "PERMISSION_HANDLER_INFO_PLIST=${plist}"

# SwiftPM caches the evaluated manifest, so a build made before this setting
# keeps every permission compiled out until the cache is gone.
rm -rf "${HOME}/Library/Developer/Xcode/DerivedData"/Runner-*
echo "Cleared Runner DerivedData. Quit and reopen Xcode before building."
