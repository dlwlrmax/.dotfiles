#!/bin/bash
# Fetch KDE Connect device status
# Output: JSON with device list + battery + signal + notifications
# {"devices":[{"id":"...","name":"...","battery":51,"charging":false,"reachable":true,"signal":4,"networkType":"LTE","notifCount":3,"notifications":[{"appName":"...","title":"...","text":"...","dismissable":true,"replyId":"...","isConversation":false}]}],"anyConnected":true}
#
# All collection happens in ONE embedded python3 process via dbus-python:
#   - no per-device / per-notification dbus-send + timeout forks
#   - no per-field python3 json_escape forks
#   - full property values via GetAll, so quotes/newlines are never truncated
#   - control chars (\x00-\x1F except \n \r \t \b \f) are stripped for valid JSON
# The JSON shape is unchanged for QML compatibility.
#
# Modes:
#   (none)                        -> full status JSON
#   dismiss <deviceId> <notifId>  -> dismiss one notification
#   dismiss-all <deviceId>        -> dismiss every dismissable notification

set -u

if ! command -v python3 &>/dev/null; then
  echo '{"devices":[],"anyConnected":false}'
  exit 0
fi

exec python3 - "$@" <<'PYEOF'
import json
import os
import subprocess
import sys
import time

try:
    import dbus
except ImportError:
    print('{"daemon":false,"devices":[],"anyConnected":false}')
    sys.exit(0)

BUS_NAME = "org.kde.kdeconnect"
BASE = "/modules/kdeconnect"
NOTIF_IFACE = "org.kde.kdeconnect.device.notifications"


def cache_dir():
    base = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
    return os.path.join(base, "quickshell", "kdeconnect")


# Notification app filter: baseline names always apply; KDECONNECT_FILTER env
# or "<cache parent>/kdeconnect-filter.txt" adds colon/newline separated names.
def load_filter():
    names = {"System UI", "Báo Mới", "Bao Moi"}
    custom = os.environ.get("KDECONNECT_FILTER", "")
    if not custom:
        path = os.path.join(os.path.dirname(cache_dir()), "kdeconnect-filter.txt")
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                custom = fh.read()
        except OSError:
            custom = ""
    for part in custom.replace("\n", ":").split(":"):
        part = part.strip()
        if part:
            names.add(part)
    return names


# Strip control characters (\x00-\x1F) that break JSON, keeping the whitespace
# escapes json.dumps already handles: \n \r \t \b \f.
_ALLOWED_CTRL = "\n\r\t\b\f"


def clean(value):
    if value is None:
        return ""
    text = str(value)
    return "".join(ch for ch in text if ord(ch) >= 0x20 or ch in _ALLOWED_CTRL)


def as_bool(value):
    try:
        return bool(value)
    except Exception:
        return False


def as_int(value):
    try:
        return int(value)
    except Exception:
        return None


def props(bus, path, iface):
    obj = bus.get_object(BUS_NAME, path, introspect=False)
    return dbus.Interface(obj, "org.freedesktop.DBus.Properties").GetAll(iface)


def read_battery(bus, dev_id, dev_path):
    """Battery percent (int|None) + charging bool, with auto-heal + last-known fallback."""
    cd = cache_dir()
    try:
        os.makedirs(cd, exist_ok=True)
    except OSError:
        pass
    last_file = os.path.join(cd, "last_battery_%s.txt" % dev_id)
    consec_file = os.path.join(cd, "consecutive_null_%s" % dev_id)
    bat_path = "%s/battery" % dev_path

    charge = None
    charging = False
    try:
        bp = props(bus, bat_path, "org.kde.kdeconnect.device.battery")
        charge = as_int(bp.get("charge"))
        charging = as_bool(bp.get("isCharging", False))
    except Exception:
        charge = None

    if charge is None or charge < 0:
        # Auto-heal: after 3 consecutive nulls (~15s) force one network refresh.
        consecutive = 0
        try:
            with open(consec_file, "r") as fh:
                consecutive = int(fh.read().strip() or 0)
        except Exception:
            consecutive = 0
        consecutive += 1
        if consecutive >= 3:
            try:
                subprocess.run(
                    ["kdeconnect-cli", "--refresh"],
                    timeout=5,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
            except Exception:
                pass
            try:
                bp = props(bus, bat_path, "org.kde.kdeconnect.device.battery")
                charge = as_int(bp.get("charge"))
                charging = as_bool(bp.get("isCharging", False))
            except Exception:
                pass
            consecutive = 0
        try:
            with open(consec_file, "w") as fh:
                fh.write(str(consecutive))
        except OSError:
            pass
    else:
        try:
            os.remove(consec_file)
        except OSError:
            pass

    if charge is not None and charge >= 0:
        try:
            with open(last_file, "w") as fh:
                fh.write(str(charge))
        except OSError:
            pass
        battery = charge
    else:
        battery = None
        try:
            with open(last_file, "r") as fh:
                cached = as_int(fh.read().strip())
            if cached is not None and cached >= 0:
                battery = cached
        except Exception:
            pass
    return battery, charging


def read_connectivity(bus, dev_path):
    """Signal strength (int|None, -1 means unknown) + network type string."""
    try:
        cp = props(bus, "%s/connectivity_report" % dev_path,
                   "org.kde.kdeconnect.device.connectivity_report")
    except Exception:
        return None, ""
    sig = as_int(cp.get("cellularNetworkStrength"))
    signal = sig if (sig is not None and sig >= 0) else None
    net = clean(cp.get("cellularNetworkType", ""))
    return signal, net


def persist_icon(app, src):
    """Copy the phone-supplied app icon (kdeconnectd keeps it in /tmp) to a
    persistent per-app file so it survives reboots; returns the stable path."""
    if not src or not os.path.isfile(src):
        return ""
    name = "".join(ch if ch.isalnum() else "_" for ch in app.lower()) or "app"
    dest_dir = os.path.join(cache_dir(), "icons")
    dest = os.path.join(dest_dir, name + ".png")
    try:
        os.makedirs(dest_dir, exist_ok=True)
        if not os.path.exists(dest) or os.path.getmtime(src) > os.path.getmtime(dest):
            with open(src, "rb") as fi, open(dest + ".tmp", "wb") as fo:
                fo.write(fi.read())
            os.replace(dest + ".tmp", dest)
    except OSError:
        return src
    return dest


def seen_times(dev_id, nids):
    """First-seen epoch per notification id (kdeconnectd exposes no timestamp).

    Persisted per device so a notification keeps its arrival time across polls;
    ids that disappeared are dropped. Accurate to the signal-driven refresh."""
    path = os.path.join(cache_dir(), "seen_%s.json" % dev_id)
    first_run = not os.path.exists(path)
    try:
        with open(path, "r") as fh:
            seen = json.load(fh)
        if not isinstance(seen, dict):
            seen = {}
    except Exception:
        seen = {}
    # On the very first run everything already present has an unknown arrival
    # time (0 -> the panel shows no time) rather than a misleading "now".
    now = 0 if first_run else int(time.time())
    current = {nid: seen.get(nid, now) for nid in nids}
    if current != seen or first_run:
        try:
            os.makedirs(cache_dir(), exist_ok=True)
            with open(path, "w") as fh:
                json.dump(current, fh)
        except OSError:
            pass
    return current


def read_notifications(bus, dev_id, filt):
    notif_path = "%s/devices/%s/notifications" % (BASE, dev_id)
    try:
        nobj = bus.get_object(BUS_NAME, notif_path, introspect=False)
        nids = [str(x) for x in
                dbus.Interface(nobj, NOTIF_IFACE).activeNotifications()]
    except Exception:
        return []

    # Match previous `sort -nr` (numeric descending).
    try:
        nids.sort(key=lambda x: -int(x))
    except (ValueError, TypeError):
        nids.sort(reverse=True)

    out = []
    times = seen_times(dev_id, nids)
    for nid in nids:
        try:
            d = props(bus, "%s/%s" % (notif_path, nid),
                      NOTIF_IFACE + ".notification")
        except Exception:
            continue

        app = clean(d.get("appName", ""))
        if app in filt:
            continue

        # Best body: text > ticker > title
        body = clean(d.get("text", "")) or clean(d.get("ticker", "")) \
            or clean(d.get("title", ""))

        title = clean(d.get("title", ""))
        icon = persist_icon(app, clean(d.get("iconPath", ""))) if as_bool(d.get("hasIcon", False)) else ""

        out.append({
            "id": nid,
            "deviceId": str(dev_id),
            "appName": app,
            "title": title if title != body else "",
            "body": body,
            "time": times.get(nid, 0),
            "iconPath": icon,
            "dismissable": as_bool(d.get("dismissable", False)),
            "silent": as_bool(d.get("silent", False)),
            "replyId": clean(d.get("replyId", "")),
            "isConversation": as_bool(d.get("isConversation", False)),
        })
    return out


def collect():
    bus = dbus.SessionBus()
    daemon = dbus.Interface(
        bus.get_object(BUS_NAME, BASE, introspect=False),
        "org.kde.kdeconnect.daemon",
    )
    # Every known device: paired ones (even when unreachable) and nearby
    # unpaired ones, so the panel can offer Pair / Reconnect.
    try:
        ids = [str(x) for x in daemon.devices(False, False)]
    except Exception:
        try:
            ids = [str(x) for x in daemon.devices()]
        except Exception:
            ids = []

    filt = load_filter()
    devices_out = []
    any_connected = False

    for dev_id in ids:
        dev_path = "%s/devices/%s" % (BASE, dev_id)
        try:
            dev_props = props(bus, dev_path, "org.kde.kdeconnect.device")
        except Exception:
            continue
        paired = as_bool(dev_props.get("isPaired", True))
        reachable = as_bool(dev_props.get("isReachable", False))
        if not paired and not reachable:
            continue
        if reachable and paired:
            any_connected = True

        if paired:
            battery, charging = read_battery(bus, dev_id, dev_path)
            signal, network = read_connectivity(bus, dev_path)
            notifications = read_notifications(bus, dev_id, filt)
        else:
            battery, charging, signal, network, notifications = None, False, None, "", []

        devices_out.append({
            "id": str(dev_id),
            "name": clean(dev_props.get("name", "")),
            "type": clean(dev_props.get("type", "")),
            "paired": paired,
            "battery": battery,
            "charging": charging,
            "reachable": reachable,
            "signal": signal,
            "networkType": network,
            "notifCount": len(notifications),
            "notifications": notifications,
        })

    return {"daemon": True, "devices": devices_out, "anyConnected": any_connected}


def notif_iface(bus, dev_id, nid):
    obj = bus.get_object(
        BUS_NAME,
        "%s/devices/%s/notifications/%s" % (BASE, dev_id, nid),
        introspect=False,
    )
    return dbus.Interface(obj, NOTIF_IFACE + ".notification")


def dismiss(dev_id, nid):
    notif_iface(dbus.SessionBus(), dev_id, nid).dismiss()


def dismiss_all(dev_id):
    bus = dbus.SessionBus()
    try:
        nobj = bus.get_object(
            BUS_NAME, "%s/devices/%s/notifications" % (BASE, dev_id),
            introspect=False)
        nids = [str(x) for x in dbus.Interface(nobj, NOTIF_IFACE).activeNotifications()]
    except Exception:
        return
    for nid in nids:
        try:
            d = props(bus, "%s/devices/%s/notifications/%s" % (BASE, dev_id, nid),
                      NOTIF_IFACE + ".notification")
        except Exception:
            continue
        if not as_bool(d.get("dismissable", False)):
            continue
        try:
            notif_iface(bus, dev_id, nid).dismiss()
        except Exception:
            pass


def main():
    args = sys.argv[1:]
    mode = args[0] if args else ""
    if mode == "dismiss":
        try:
            dismiss(args[1] if len(args) > 1 else "",
                    args[2] if len(args) > 2 else "")
        except Exception:
            pass
        return
    if mode == "dismiss-all":
        try:
            dismiss_all(args[1] if len(args) > 1 else "")
        except Exception:
            pass
        return
    try:
        print(json.dumps(collect(), ensure_ascii=False, separators=(",", ":")))
    except Exception:
        print('{"daemon":false,"devices":[],"anyConnected":false}')


main()
PYEOF
