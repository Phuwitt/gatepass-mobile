#!/bin/bash
set -euo pipefail
TASK_APP_ROOT=$(cd "$(dirname "$0")/.." && pwd)
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export PATH="$(ruby -r rubygems -e 'print Gem.user_dir')/bin:$PATH"
# Build outside FileProvider-synced Documents: FinderInfo on generated frameworks
# causes codesign to fail. Original project files stay in place.
TASK_IOS_STAGE=$(python3 "$TASK_APP_ROOT/tool/stage_ios.py")
cd "$TASK_IOS_STAGE"
flutter pub get
flutter build ios --simulator --debug --config-only --no-codesign
cd ios
pod install
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$TASK_IOS_STAGE/derived" \
  ARCHS="$(uname -m)" ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
mkdir -p "$TASK_APP_ROOT/dist"
ditto -c -k --norsrc --noextattr --keepParent \
  "$TASK_IOS_STAGE/derived/Build/Products/Debug-iphonesimulator/Runner.app" \
  "$TASK_APP_ROOT/dist/GATEPASS-ios-simulator.zip"
echo "Simulator build: $TASK_APP_ROOT/dist/GATEPASS-ios-simulator.zip"
echo "Build workspace preserved for diagnostics: $TASK_IOS_STAGE"
