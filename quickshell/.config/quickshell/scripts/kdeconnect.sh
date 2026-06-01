#!/bin/bash
# Fetch KDE Connect device status
# Output: JSON with device list + battery + signal + notifications
# {"devices":[{"id":"...","name":"...","battery":51,"charging":false,"reachable":true,"signal":4,"networkType":"LTE","notifCount":3,"notifications":[{"appName":"...","title":"...","text":"...","dismissable":true}]}],"anyConnected":true}

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/kdeconnect"
CACHE_FILE="$CACHE_DIR/devices.json"
LAST_BATTERY_FILE="$CACHE_DIR/last_battery.txt"
CACHE_TTL=3

if ! command -v kdeconnect-cli &>/dev/null; then
  echo '{"devices":[],"anyConnected":false}'
  exit 0
fi

# Dismiss notification mode: ./kdeconnect.sh dismiss <deviceId> <notifId>
if [ "${1:-}" = "dismiss" ]; then
  dbus-send --print-reply --dest=org.kde.kdeconnect \
    "/modules/kdeconnect/devices/${2}/notifications/${3}" \
    org.kde.kdeconnect.device.notifications.notification.dismiss
  # Invalidate cache so next poll picks up changes
  rm -f "$CACHE_FILE"
  exit 0
fi

# Cache hit? Return cached data if fresh enough
if [ -f "$CACHE_FILE" ]; then
  now=$(date +%s)
  mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null)
  age=$((now - mtime))
  if [ "$age" -lt "$CACHE_TTL" ]; then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

devices=$(kdeconnect-cli -a --id-name-only 2>/dev/null)
if [ -z "$devices" ]; then
  echo '{"devices":[],"anyConnected":false}'
  exit 0
fi

output='{"devices":['
first=true

while IFS= read -r line; do
  [ -z "$line" ] && continue
  id=$(echo "$line" | awk '{print $1}')
  name=$(echo "$line" | cut -d' ' -f2-)

  battery=null
  charging="false"
  signal=null
  networkType=""
  notifCount=0
  notifJson=""

  if [ -n "$id" ]; then
    # Battery — GetAll gets charge + isCharging in one call
    bat_raw=$(dbus-send --print-reply --dest=org.kde.kdeconnect \
      "/modules/kdeconnect/devices/${id}/battery" \
      org.freedesktop.DBus.Properties.GetAll \
      string:"org.kde.kdeconnect.device.battery" 2>/dev/null)
    charge=$(echo "$bat_raw" | grep -A1 'string "charge"' | tail -1 | grep -oP 'int32 \K-?\d+')

    # Auto-heal: if battery unknown, try refreshing connection
    if [ -z "$charge" ] || [ "$charge" -lt 0 ] 2>/dev/null; then
      consecutive_file="$CACHE_DIR/consecutive_null_${id}"
      consecutive=0
      [ -f "$consecutive_file" ] && consecutive=$(cat "$consecutive_file")
      consecutive=$((consecutive + 1))
      echo "$consecutive" > "$consecutive_file"

      # After 3 consecutive nulls (~15s), force network refresh
      if [ "$consecutive" -ge 3 ]; then
        kdeconnect-cli --refresh 2>/dev/null
        sleep 1
        bat_raw=$(dbus-send --print-reply --dest=org.kde.kdeconnect \
          "/modules/kdeconnect/devices/${id}/battery" \
          org.freedesktop.DBus.Properties.GetAll \
          string:"org.kde.kdeconnect.device.battery" 2>/dev/null)
        charge=$(echo "$bat_raw" | grep -A1 'string "charge"' | tail -1 | grep -oP 'int32 \K-?\d+')
      fi

      # After 6 consecutive nulls (~30s), kill & restart kdeconnectd
      if [ "$consecutive" -ge 6 ]; then
        pkill kdeconnectd 2>/dev/null
        sleep 2
        rm -f "$consecutive_file"
      fi
    else
      # Valid battery — reset consecutive counter
      rm -f "$CACHE_DIR/consecutive_null_${id}" 2>/dev/null
    fi

    if [ -n "$charge" ] && [ "$charge" -ge 0 ] 2>/dev/null; then
      battery=$charge
      echo "$id $battery" > "$LAST_BATTERY_FILE"
    else
      # Fallback: use last known battery from cache
      if [ -f "$LAST_BATTERY_FILE" ]; then
        cached=$(grep "^${id} " "$LAST_BATTERY_FILE" | awk '{print $2}')
        [ -n "$cached" ] && [ "$cached" -ge 0 ] 2>/dev/null && battery=$cached
      fi
    fi
    isch=$(echo "$bat_raw" | grep -A1 'string "isCharging"' | tail -1 | grep -oP 'boolean \K\w+')
    [ "$isch" = "true" ] && charging="true"

    # Connectivity — GetAll gets strength + type in one call
    conn_raw=$(dbus-send --print-reply --dest=org.kde.kdeconnect \
      "/modules/kdeconnect/devices/${id}/connectivity_report" \
      org.freedesktop.DBus.Properties.GetAll \
      string:"org.kde.kdeconnect.device.connectivity_report" 2>/dev/null)
    sig=$(echo "$conn_raw" | grep -A1 'string "cellularNetworkStrength"' | tail -1 | grep -oP 'int32 \K-?\d+')
    if [ -n "$sig" ] && [ "$sig" -ge 0 ] 2>/dev/null; then signal=$sig; fi
    net=$(echo "$conn_raw" | grep -A1 'string "cellularNetworkType"' | tail -1 | grep -oP 'string "\K[^"]+')
    [ -n "$net" ] && networkType="$net"

    # Notifications
    raw_ids=$(dbus-send --print-reply --dest=org.kde.kdeconnect \
      "/modules/kdeconnect/devices/${id}/notifications" \
      org.kde.kdeconnect.device.notifications.activeNotifications 2>/dev/null)
    ids=$(echo "$raw_ids" | grep -oP 'string "\K[^"]+' 2>/dev/null)
    if [ -n "$ids" ]; then
      count=0
      for nid in $ids; do
        [ -z "$nid" ] && continue
        raw_notif=$(dbus-send --print-reply --dest=org.kde.kdeconnect \
          "/modules/kdeconnect/devices/${id}/notifications/${nid}" \
          org.freedesktop.DBus.Properties.GetAll \
          string:"org.kde.kdeconnect.device.notifications.notification" 2>/dev/null)

        app=$(echo "$raw_notif" | grep -A1 'string "appName"' | tail -1 | grep -oP 'string "\K[^"]+')
        title=$(echo "$raw_notif" | grep -A1 'string "title"' | tail -1 | grep -oP 'string "\K[^"]+')
        text=$(echo "$raw_notif" | grep -A1 'string "text"' | tail -1 | grep -oP 'string "\K[^"]+')
        ticker=$(echo "$raw_notif" | grep -A1 'string "ticker"' | tail -1 | grep -oP 'string "\K[^"]+')
        dismiss=$(echo "$raw_notif" | grep -A1 'string "dismissable"' | tail -1 | grep -oP '(true|false)')
        [ -z "$dismiss" ] && dismiss="false"

        # Best body: text > ticker > title
        body="$text"
        [ -z "$body" ] && body="$ticker"
        [ -z "$body" ] && body="$title"

        # Filter unwanted apps
        case "$app" in
          "System UI"|"Báo Mới"|"Bao Moi") continue ;;
        esac

        # Escape JSON strings
        app=$(echo "$app" | sed 's/"/\\"/g')
        body=$(echo "$body" | sed 's/"/\\"/g')

        [ "$count" -gt 0 ] && notifJson="$notifJson,"
        notifJson="$notifJson{\"id\":\"${nid}\",\"deviceId\":\"${id}\",\"appName\":\"$app\",\"body\":\"$body\",\"dismissable\":$dismiss}"
        count=$((count + 1))
      done
      notifCount=$count
    fi
  fi

  [ "$first" = true ] && first=false || output="$output,"
  output="$output{\"id\":\"${id}\",\"name\":\"${name}\",\"battery\":${battery},\"charging\":${charging},\"reachable\":true,\"signal\":${signal},\"networkType\":\"${networkType}\",\"notifCount\":${notifCount},\"notifications\":[${notifJson}]}"
done <<< "$devices"

output="$output],\"anyConnected\":true}"

# Write cache
mkdir -p "$CACHE_DIR"
echo "$output" > "$CACHE_FILE"

echo "$output"
