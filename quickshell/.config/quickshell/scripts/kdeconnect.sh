#!/bin/bash
# Fetch KDE Connect device status
# Output: JSON with device list + battery + signal + notifications
# {"devices":[{"id":"...","name":"...","battery":51,"charging":false,"reachable":true,"signal":4,"networkType":"LTE","notifCount":3,"notifications":[{"appName":"...","title":"...","text":"...","dismissable":true}]}],"anyConnected":true}

if ! command -v kdeconnect-cli &>/dev/null; then
  echo '{"devices":[],"anyConnected":false}'
  exit 0
fi

devices=$(kdeconnect-cli -a --id-name-only 2>/dev/null)
if [ -z "$devices" ]; then
  echo '{"devices":[],"anyConnected":false}'
  exit 0
fi

echo -n '{"devices":['
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
  notifications=""
  notifJson=""

  if [ -n "$id" ]; then
    # Battery
    raw=$(dbus-send --print-reply --dest=org.kde.kdeconnect \
      "/modules/kdeconnect/devices/${id}/battery" \
      org.freedesktop.DBus.Properties.Get \
      string:"org.kde.kdeconnect.device.battery" string:"charge" 2>/dev/null)
    charge=$(echo "$raw" | grep -oP 'int32 \K\d+' 2>/dev/null)
    [ -n "$charge" ] && battery=$charge

    raw_c=$(dbus-send --print-reply --dest=org.kde.kdeconnect \
      "/modules/kdeconnect/devices/${id}/battery" \
      org.freedesktop.DBus.Properties.Get \
      string:"org.kde.kdeconnect.device.battery" string:"isCharging" 2>/dev/null)
    isch=$(echo "$raw_c" | grep -oP 'boolean \K\w+' 2>/dev/null)
    [ "$isch" = "true" ] && charging="true"

    # Signal
    raw_s=$(dbus-send --print-reply --dest=org.kde.kdeconnect \
      "/modules/kdeconnect/devices/${id}/connectivity_report" \
      org.freedesktop.DBus.Properties.Get \
      string:"org.kde.kdeconnect.device.connectivity_report" string:"cellularNetworkStrength" 2>/dev/null)
    sig=$(echo "$raw_s" | grep -oP 'int32 \K\d+' 2>/dev/null)
    [ -n "$sig" ] && signal=$sig

    raw_n=$(dbus-send --print-reply --dest=org.kde.kdeconnect \
      "/modules/kdeconnect/devices/${id}/connectivity_report" \
      org.freedesktop.DBus.Properties.Get \
      string:"org.kde.kdeconnect.device.connectivity_report" string:"cellularNetworkType" 2>/dev/null)
    net=$(echo "$raw_n" | grep -oP 'string "\K[^"]+' 2>/dev/null)
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

        # Escape JSON strings
        app=$(echo "$app" | sed 's/"/\\"/g')
        body=$(echo "$body" | sed 's/"/\\"/g')

        [ "$count" -gt 0 ] && notifJson="$notifJson,"
        notifJson="$notifJson{\"appName\":\"$app\",\"body\":\"$body\",\"dismissable\":$dismiss}"
        count=$((count + 1))
      done
      notifCount=$count
    fi
  fi

  [ "$first" = true ] && first=false || echo -n ','
  echo -n "{\"id\":\"${id}\",\"name\":\"${name}\",\"battery\":${battery},\"charging\":${charging},\"reachable\":true,\"signal\":${signal},\"networkType\":\"${networkType}\",\"notifCount\":${notifCount},\"notifications\":[${notifJson}]}"
done <<< "$devices"

echo '],"anyConnected":true}'
