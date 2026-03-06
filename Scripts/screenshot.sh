#!/bin/zsh

set -euo pipefail

source config.sh

# Generate timestamped filename
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SCREENSHOT_PATH="screenshot-${TIMESTAMP}.png"

# Get the FlaschenTaschen window ID
WINDOW_ID=$(windows | grep "$BUNDLE_ID" | awk '{print $1}' | head -1)

if [ -n "$WINDOW_ID" ]; then
    echo "Capturing FlaschenTaschen window ($WINDOW_ID)..."
    screencapture -l "$WINDOW_ID" "$SCREENSHOT_PATH"
    echo "✓ Screenshot saved: $SCREENSHOT_PATH"
else
    echo "App window not found, capturing full screen..."
    screencapture -x "$SCREENSHOT_PATH"
    echo "✓ Screenshot saved: $SCREENSHOT_PATH"
fi
