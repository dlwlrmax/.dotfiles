#!/bin/bash
# Fetch KDE Connect device status
# Output: JSON with device list + battery + signal + notifications
# {"devices":[{"id":"...","name":"...","battery":51,"charging":false,"reachable":true,"signal":4,"networkType":"LTE","notifCount":3,"notifications":[{"appName":"...","title":"...","text":"...","dismissable":true,"replyId":"...","isConversation":false}]}],"anyConnected":true}

set -u

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/kdeconnect"

# Notification app filter: colon-separated custom names from KDECONNECT_FILTER
# env or "$CACHE_DIR/../kdeconnect-filter.txt". Baseline filters always apply.
NOTIF_FILTER_FILE="$CACHE_DIR/../kdeconnect-filter.txt"
custom_filter="${KDECONNECT_FILTER:-}"
if [ -z "$custom_filter" ] && [ -f "$NOTIF_FILTER_FILE" ]; then
  custom_filter=$(cat "$NOTIF_FILTER_FILE" 2>/dev/null)
fi
custom_filter=$(printf '%s' "$custom_filter" | tr '\n' ':')

# True if the app should be filtered out of the notification list.
is_filtered() {
  local app="${1-}"
  case "$app" in
    "System UI"|"Báo Mới"|"Bao Moi") return 0 ;;
  esac
  if [ -n "$custom_filter" ]; then
    local IFS=:
    local f
    for f in $custom_filter; do
      f="${f#"${f%%[![:space:]]*}"}"
      f="${f%"${f##*[![:space:]]}"}"
      [ -n "$f" ] && [ "$app" = "$f" ] && return 0
    done
  fi
  return 1
}

# Escape a string for embedding in a JSON string value (without surrounding quotes).
if command -v python3 &>/dev/null; then
  json_escape() {
    printf '%s' "${1-}" | python3 -c 'import sys,json; sys.stdout.write(json.dumps(sys.stdin.read(), ensure_ascii=False)[1:-1])'
  }
else
  json_escape() {
    local s="${1-}"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    s="${s//$'\b'/\\b}"
    s="${s//$'\f'/\\f}"
    printf '%s' "$s"
  }
fi

if ! command -v kdeconnect-cli &>/dev/null; then
  echo '{"devices":[],"anyConnected":false}'
  exit 0
fi

# Dismiss notification mode: ./kdeconnect.sh dismiss <deviceId> <notifId>
if [ "${1:-}" = "dismiss" ]; then
  timeout 5 dbus-send --print-reply --dest=org.kde.kdeconnect \
    "/modules/kdeconnect/devices/${2:-}/notifications/${3:-}" \
    org.kde.kdeconnect.device.notifications.notification.dismiss
  exit 0
fi

# Dismiss-all mode: ./kdeconnect.sh dismiss-all <deviceId>
# One process dismisses every dismissable notification. Ongoing stays.
if [ "${1:-}" = "dismiss-all" ]; then
  dev="${2:-}"
  raw_ids=$(timeout 5 dbus-send --print-reply --dest=org.kde.kdeconnect \
    "/modules/kdeconnect/devices/${dev}/notifications" \
    org.kde.kdeconnect.device.notifications.activeNotifications 2>/dev/null)
  echo "$raw_ids" | grep -oP 'string "\K[^"]+' 2>/dev/null | while read -r nid; do
    [ -z "$nid" ] && continue
    is_dismiss=$(timeout 5 dbus-send --print-reply --dest=org.kde.kdeconnect \
      "/modules/kdeconnect/devices/${dev}/notifications/${nid}" \
      org.freedesktop.DBus.Properties.GetAll \
      string:"org.kde.kdeconnect.device.notifications.notification" 2>/dev/null \
      | grep -A1 'string "dismissable"' | tail -1 | grep -oP '(true|false)')
    [ "$is_dismiss" = "true" ] || continue
    timeout 5 dbus-send --print-reply --dest=org.kde.kdeconnect \
      "/modules/kdeconnect/devices/${dev}/notifications/${nid}" \
      org.kde.kdeconnect.device.notifications.notification.dismiss >/dev/null 2>&1
  done
  exit 0
fi

# All paired devices (reachable or not); reachability derived from the
# available list below. Note: this kdeconnect-cli has no `-c` flag — `-l`
# lists all paired devices and `-a` lists available (paired + reachable) ones.
devices=$(kdeconnect-cli -l --id-name-only 2>/dev/null)
if [ -z "$devices" ]; then
  echo '{"devices":[],"anyConnected":false}'
  exit 0
fi

# Reachable device ids: a paired device absent here is not reachable.
connected=$(kdeconnect-cli -a --id-name-only 2>/dev/null)

output='{"devices":['
first=true
anyConnected=false

while IFS= read -r line; do
  [ -z "$line" ] && continue
  id=$(echo "$line" | awk '{print $1}')
  name=$(json_escape "$(echo "$line" | cut -d' ' -f2-)")

  reachable=false
  if [ -n "$id" ] && [ -n "$connected" ] && \
     echo "$connected" | awk '{print $1}' | grep -qxF "$id"; then
    reachable=true
    anyConnected=true
  fi

  battery=null
  charging="false"
  signal=null
  networkType=""
  notifCount=0
  notifJson=""
  last_battery_file="$CACHE_DIR/last_battery_${id}.txt"

  if [ -n "$id" ]; then
    # Battery — GetAll gets charge + isCharging in one call
    bat_raw=$(timeout 5 dbus-send --print-reply --dest=org.kde.kdeconnect \
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

      # After 3 consecutive nulls (~15s), force one network refresh, then reset
      # the counter to 0 so the next attempt needs another full threshold.
      if [ "$consecutive" -ge 3 ]; then
        kdeconnect-cli --refresh 2>/dev/null
        bat_raw=$(timeout 5 dbus-send --print-reply --dest=org.kde.kdeconnect \
          "/modules/kdeconnect/devices/${id}/battery" \
          org.freedesktop.DBus.Properties.GetAll \
          string:"org.kde.kdeconnect.device.battery" 2>/dev/null)
        charge=$(echo "$bat_raw" | grep -A1 'string "charge"' | tail -1 | grep -oP 'int32 \K-?\d+')
        consecutive=0
      fi
      echo "$consecutive" > "$consecutive_file"
    else
      # Valid battery — reset consecutive counter
      rm -f "$CACHE_DIR/consecutive_null_${id}" 2>/dev/null
    fi

    if [ -n "$charge" ] && [ "$charge" -ge 0 ] 2>/dev/null; then
      battery=$charge
      echo "$battery" > "$last_battery_file"
    else
      # Fallback: use last known battery for this device
      if [ -f "$last_battery_file" ]; then
        cached=$(cat "$last_battery_file" 2>/dev/null)
        [ -n "$cached" ] && [ "$cached" -ge 0 ] 2>/dev/null && battery=$cached
      fi
    fi
    isch=$(echo "$bat_raw" | grep -A1 'string "isCharging"' | tail -1 | grep -oP 'boolean \K\w+')
    [ "$isch" = "true" ] && charging="true"

    # Connectivity — GetAll gets strength + type in one call
    conn_raw=$(timeout 5 dbus-send --print-reply --dest=org.kde.kdeconnect \
      "/modules/kdeconnect/devices/${id}/connectivity_report" \
      org.freedesktop.DBus.Properties.GetAll \
      string:"org.kde.kdeconnect.device.connectivity_report" 2>/dev/null)
    sig=$(echo "$conn_raw" | grep -A1 'string "cellularNetworkStrength"' | tail -1 | grep -oP 'int32 \K-?\d+')
    if [ -n "$sig" ] && [ "$sig" -ge 0 ] 2>/dev/null; then signal=$sig; fi
    net=$(echo "$conn_raw" | grep -A1 'string "cellularNetworkType"' | tail -1 | grep -oP 'string "\K[^"]+')
    [ -n "$net" ] && networkType="$net"
    networkType=$(json_escape "$networkType")

    # Notifications
    raw_ids=$(timeout 5 dbus-send --print-reply --dest=org.kde.kdeconnect \
      "/modules/kdeconnect/devices/${id}/notifications" \
      org.kde.kdeconnect.device.notifications.activeNotifications 2>/dev/null)
    ids=$(echo "$raw_ids" | grep -oP 'string "\K[^"]+' 2>/dev/null | sort -nr | tr '\n' ' ')
    if [ -n "$ids" ]; then
      count=0
      for nid in $ids; do
        [ -z "$nid" ] && continue
        raw_notif=$(timeout 5 dbus-send --print-reply --dest=org.kde.kdeconnect \
          "/modules/kdeconnect/devices/${id}/notifications/${nid}" \
          org.freedesktop.DBus.Properties.GetAll \
          string:"org.kde.kdeconnect.device.notifications.notification" 2>/dev/null)

        app=$(echo "$raw_notif" | grep -A1 'string "appName"' | tail -1 | grep -oP 'string "\K[^"]+')
        title=$(echo "$raw_notif" | grep -A1 'string "title"' | tail -1 | grep -oP 'string "\K[^"]+')
        text=$(echo "$raw_notif" | grep -A1 'string "text"' | tail -1 | grep -oP 'string "\K[^"]+')
        ticker=$(echo "$raw_notif" | grep -A1 'string "ticker"' | tail -1 | grep -oP 'string "\K[^"]+')
        dismiss=$(echo "$raw_notif" | grep -A1 'string "dismissable"' | tail -1 | grep -oP '(true|false)')
        [ -z "$dismiss" ] && dismiss="false"
        silent=$(echo "$raw_notif" | grep -A1 'string "silent"' | tail -1 | grep -oP 'boolean \K\w+')
        [ -z "$silent" ] && silent="false"

        reply_id=$(echo "$raw_notif" | grep -A1 'string "replyId"' | tail -1 | grep -oP 'string "\K[^"]+')
        reply_id=$(json_escape "$reply_id")
        is_conv=$(echo "$raw_notif" | grep -A1 'string "isConversation"' | tail -1 | grep -oP 'boolean \K\w+')
        [ -z "$is_conv" ] && is_conv="false"

        # Best body: text > ticker > title
        body="$text"
        [ -z "$body" ] && body="$ticker"
        [ -z "$body" ] && body="$title"

        # Filter unwanted apps
        if is_filtered "$app"; then continue; fi

        # Escape JSON strings (backslash first, then quote + control chars)
        app=$(json_escape "$app")
        body=$(json_escape "$body")

        [ "$count" -gt 0 ] && notifJson="$notifJson,"
        notifJson="$notifJson{\"id\":\"${nid}\",\"deviceId\":\"${id}\",\"appName\":\"$app\",\"body\":\"$body\",\"dismissable\":$dismiss,\"silent\":$silent,\"replyId\":\"${reply_id}\",\"isConversation\":$is_conv}"
        count=$((count + 1))
      done
      notifCount=$count
    fi
  fi

  [ "$first" = true ] && first=false || output="$output,"
  output="$output{\"id\":\"${id}\",\"name\":\"${name}\",\"battery\":${battery},\"charging\":${charging},\"reachable\":${reachable},\"signal\":${signal},\"networkType\":\"${networkType}\",\"notifCount\":${notifCount},\"notifications\":[${notifJson}]}"
done <<< "$devices"

output="$output],\"anyConnected\":${anyConnected}}"

echo "$output"
