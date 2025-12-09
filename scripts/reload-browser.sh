#!/bin/bash

set -e

echo "Closing browsers..."

# Close Google Chrome
pkill -9 -f "google-chrome" 2>/dev/null || true
pkill -9 -f "chrome" 2>/dev/null || true
echo "Attempting to close Google Chrome"

# Close Zen-browser
pkill -9 -f "zen-browser" 2>/dev/null || true
echo "Attempting to close Zen-browser"

# Wait a moment for processes to fully close
sleep 2

echo "Reopening browsers..."

# Reopen Google Chrome
if command -v google-chrome-stable > /dev/null; then
    google-chrome-stable &
    echo "Google Chrome reopened"
elif command -v google-chrome > /dev/null; then
    google-chrome &
    echo "Google Chrome reopened"
else
    echo "Google Chrome not found"
fi

# Reopen Zen-browser
if command -v zen-browser > /dev/null; then
    zen-browser &
    echo "Zen-browser reopened"
else
    echo "Zen-browser not found"
fi

echo "Browser reload complete"
