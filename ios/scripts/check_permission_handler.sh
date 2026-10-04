#!/bin/sh
# Fails the build when permission_handler was compiled without the
# permissions the app asks for.
#
# Under Swift Package Manager, permission_handler_apple's Package.swift turns
# each permission on only if it finds the matching NS*UsageDescription in our
# Info.plist. It finds the plist through the build's working directory, which
# works for `flutter build ios`, `flutter run` and xcodebuild started inside
# the repo, but not for builds started from Xcode.app (working directory "/").
# There every permission is compiled out, the build still succeeds, and
# Permission.locationAlways reports `denied` forever. Run
# ios/scripts/xcode_app_env.sh once to fix Xcode.app builds.
#
# A compiled-out location permission leaves LocationPermissionStrategy as an
# empty stub, so the real strategy's selector initWithLocationManager is
# missing from the binary. Selector names survive stripping. Motion (sensors)
# has no such marker, but it is decided from the same Info.plist, so a build
# that has location has motion too.

set -e

app="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
binaries="${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}"
# Debug builds from Xcode put the app's code in Runner.debug.dylib.
[ -f "${app}/${EXECUTABLE_NAME}.debug.dylib" ] && binaries="${binaries} ${app}/${EXECUTABLE_NAME}.debug.dylib"

if ! strings -a ${binaries} 2>/dev/null | grep -qx initWithLocationManager; then
  echo "error: permission_handler was built without its permissions: location and motion would always report 'denied'." >&2
  echo "error: Xcode.app build? Quit Xcode, run ios/scripts/xcode_app_env.sh, reopen Xcode and build again." >&2
  exit 1
fi
echo "permission_handler: location and motion permissions are compiled in"
