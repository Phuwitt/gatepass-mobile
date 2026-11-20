#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# CocoaPods installed in the user's Ruby gem directory; no global shell edits.
if command -v ruby >/dev/null 2>&1; then
  export PATH="$(ruby -r rubygems -e 'print Gem.user_dir')/bin:$PATH"
fi
if [ -d /opt/homebrew/opt/ruby/bin ]; then
  export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
  export PATH="$(/opt/homebrew/opt/ruby/bin/ruby -r rubygems -e 'print Gem.user_dir')/bin:$PATH"
fi
flutter pub get
flutter run "$@"
