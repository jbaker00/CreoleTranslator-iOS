#!/bin/sh
set -e

# Auto-increment build number on Xcode Cloud.
# CI_BUILD_NUMBER is provided by Xcode Cloud and increments with each build.
# The offset (43) accounts for builds already manually submitted to App Store Connect.
OFFSET=43
BUILD_NUMBER=$((CI_BUILD_NUMBER + OFFSET))

echo "Setting build number to $BUILD_NUMBER (CI_BUILD_NUMBER=$CI_BUILD_NUMBER + offset=$OFFSET)"
xcrun agvtool new-version -all "$BUILD_NUMBER"
