#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
: "${LONGX_SIGNING_IDENTITY:?Set LONGX_SIGNING_IDENTITY to a Developer ID Application certificate name or SHA-1}"
: "${LONGX_NOTARY_PROFILE:?Set LONGX_NOTARY_PROFILE to your notarytool keychain profile name}"
identity_line=$(security find-identity -v -p codesigning | /usr/bin/grep -F -- "$LONGX_SIGNING_IDENTITY" || true)
if [[ "$identity_line" != *'Developer ID Application:'* ]]; then
  print -u2 'A valid Developer ID Application identity with its private key is required.'
  exit 1
fi
xcrun notarytool history --keychain-profile "$LONGX_NOTARY_PROFILE" >/dev/null
release_work=$(mktemp -d /private/tmp/longx-release.XXXXXX)
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
cleanup() {
  [[ ! -d "$release_work/DerivedData/Build/Products/Release/LongX.app" ]] || "$lsregister" -u "$release_work/DerivedData/Build/Products/Release/LongX.app" >/dev/null 2>&1 || true
  rm -rf -- "$release_work"
}
trap cleanup EXIT
xcodebuild -project LongX.xcodeproj -scheme LongX -configuration Release \
  -derivedDataPath "$release_work/DerivedData" CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=NO 'ARCHS=arm64 x86_64' build
release_app="$release_work/DerivedData/Build/Products/Release/LongX.app"
codesign --force --sign "$LONGX_SIGNING_IDENTITY" --options runtime --timestamp \
  --entitlements LongX/LongX.entitlements "$release_app"
codesign --verify --deep --strict --verbose=2 "$release_app"
ditto -c -k --keepParent "$release_app" "$release_work/submission.zip"
xcrun notarytool submit "$release_work/submission.zip" --keychain-profile "$LONGX_NOTARY_PROFILE" --wait
xcrun stapler staple "$release_app"
xcrun stapler validate "$release_app"
spctl --assess --type execute --verbose=2 "$release_app"
release_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$release_app/Contents/Info.plist")
release_zip="dist/LongX-${release_version}-macOS-universal.zip"
mkdir -p dist
ditto -c -k --keepParent "$release_app" "$release_work/final.zip"
mv "$release_work/final.zip" "$release_zip"
shasum -a 256 "$release_zip" > "$release_zip.sha256"
print "Signed and notarized release: $PWD/$release_zip"
