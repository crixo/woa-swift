#!/bin/bash

# chmod +x unlock-woa.sh
# ./unlock-woa.sh equivalent to ./unlock-woa.sh /Applications/WOA.app
# ./unlock-woa.sh /path/to/WOA.app


DEFAULT_APP="/Applications/WOA.app"

APP="${1:-$DEFAULT_APP}"

if [ ! -d "$APP" ]; then
    echo "Error: application not found"
    echo "Path: $APP"
    exit 1
fi

echo "Application: $APP"
echo

echo "Gatekeeper assessment:"
spctl -a -vv "$APP" 2>&1
echo

echo "Removing quarantine attribute..."
sudo xattr -rd com.apple.quarantine "$APP"
echo

if xattr -p com.apple.quarantine "$APP" >/dev/null 2>&1; then
    echo "Quarantine attribute still present"
    exit 1
fi

echo "Quarantine attribute removed"