#!/bin/sh
# Builds the personalized Release app bundle for this fork.
#
# The upstream Release configuration signs with the project owner's Developer ID
# and development team, which this fork does not have. The build therefore
# overrides signing with an ad-hoc identity and uses its own bundle identifier so
# the app can coexist with an official Easydict installation.
#
# Environment overrides:
#   BUNDLE_ID     bundle identifier (default com.cahlina.easydict)
#   DERIVED_DATA  build directory
#   CONFIGURATION build configuration (default Release)
set -eu

cd "$(dirname "$0")/.."

BUNDLE_ID="${BUNDLE_ID:-com.cahlina.easydict}"
CONFIGURATION="${CONFIGURATION:-Release}"
CHECKOUT_ID="$(git rev-parse --show-toplevel | sed -e "s|^$HOME/||" -e 's|^\.||' -e 's|/|_|g')"
DERIVED_DATA="${DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Easydict-Agent/$CHECKOUT_ID-release}"

xcodebuild build \
  -workspace Easydict.xcworkspace \
  -scheme Easydict \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/Easydict.app"

# Signing is off for the build, so ad-hoc sign the bundle here: an unsigned
# executable cannot start on Apple silicon.
FRAMEWORKS_DIR="$APP_PATH/Contents/Frameworks"
if [ -d "$FRAMEWORKS_DIR" ]; then
  find "$FRAMEWORKS_DIR" -maxdepth 1 -name '*.framework' -print0 |
    while IFS= read -r -d '' framework; do
      codesign --force --sign - "$framework"
    done
fi
codesign --force --sign - "$APP_PATH"
codesign --verify --strict "$APP_PATH"

echo
echo "built: $APP_PATH"
echo "bundle id: $(plutil -extract CFBundleIdentifier raw "$APP_PATH/Contents/Info.plist")"
echo "signature: $(codesign -dv "$APP_PATH" 2>&1 | grep -m1 Signature)"
