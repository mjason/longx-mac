#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodebuild -project LongX.xcodeproj -scheme LongX -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- build
printf '\nApp: %s/build/Build/Products/Release/LongX.app\n' "$PWD"
