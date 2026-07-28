#!/bin/bash
# Play notification sound — portable across machines
# Uses Nextcloud-synced sound if available, otherwise silent
set -e

SOUND="$HOME/Nextcloud/Sounds/notification.wav"

if [ -f "$SOUND" ] && command -v paplay &>/dev/null; then
    paplay "$SOUND"
fi
# Silent fallback on machines without the sound file or paplay
