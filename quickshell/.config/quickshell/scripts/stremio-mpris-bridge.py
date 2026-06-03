#!/usr/bin/env python3
"""Stremio -> MPRIS bridge via PulseAudio media.name polling.

Polls pactl for Stremio/mpv audio streams, extracts media title,
registers org.mpris.MediaPlayer2.stremio on D-Bus.
QuickShell picks it up -> title in bar.

No GLib dependency — uses threaded D-Bus + time.sleep loop (~20MB lighter).
"""

import dbus
import dbus.service
import dbus.mainloop.threaded
import subprocess
import re
import threading
import time
import signal
import sys

BUS_NAME = 'org.mpris.MediaPlayer2.stremio'
OBJ_PATH = '/org/mpris/MediaPlayer2'
IFACE_MPRIS = 'org.mpris.MediaPlayer2'
IFACE_PLAYER = 'org.mpris.MediaPlayer2.Player'
TRACK_ID = dbus.String(OBJ_PATH + '/track/0')


def parse_sink_inputs(output: str) -> list[dict]:
    """Parse `pactl list sink-inputs` into list of dicts."""
    streams: list[dict] = []
    current: dict | None = None
    in_props = False

    for line in output.split('\n'):
        if line.startswith('Sink Input #'):
            if current and current.get('index'):
                streams.append(current)
            m = re.search(r'#(\d+)', line)
            current = {'index': m.group(1)} if m else {}
            in_props = False
        elif current is not None:
            s = line.strip()
            if s == 'Properties:':
                in_props = True
            elif in_props and '=' in s:
                key, _, val = s.partition('=')
                current[key.strip()] = val.strip().strip('"')
            elif not s:
                in_props = False

    if current and current.get('index'):
        streams.append(current)
    return streams


# ── MPRIS D-Bus service (runs on its own thread) ──────────


class StremioPlayer(dbus.service.Object):
    """Read-only MPRIS player. PlaybackStatus + Metadata updated externally."""

    def __init__(self, bus_name):
        super().__init__(bus_name, OBJ_PATH)
        self._lock = threading.Lock()
        self._title = ''
        self._status = 'Stopped'

    def set_playing(self, title: str):
        with self._lock:
            changed = {}
            if title != self._title:
                self._title = title
                changed['Metadata'] = self._metadata()
            if self._status != 'Playing':
                self._status = 'Playing'
                changed['PlaybackStatus'] = self._status
            if changed:
                self.PropertiesChanged(IFACE_PLAYER, changed, [])

    def set_stopped(self):
        with self._lock:
            if self._status == 'Stopped' and not self._title:
                return
            self._title = ''
            self._status = 'Stopped'
            self.PropertiesChanged(IFACE_PLAYER,
                                   {'PlaybackStatus': 'Stopped',
                                    'Metadata': self._metadata()}, [])

    def _metadata(self) -> dbus.Dictionary:
        return dbus.Dictionary({
            'mpris:trackid': TRACK_ID,
            'mpris:length': dbus.Int64(0),
            'xesam:title': dbus.String(self._title or ''),
            'xesam:artist': dbus.String('Stremio'),
        }, signature='sv', variant_level=1)

    # ── Properties interface ──────────────────────────────

    @dbus.service.method(dbus.PROPERTIES_IFACE,
                         in_signature='ss', out_signature='v')
    def Get(self, iface, prop):
        if iface == IFACE_MPRIS:
            return {
                'Identity': 'Stremio',
                'DesktopEntry': 'com.stremio.Stremio',
                'SupportedUriSchemes': dbus.Array([], 's'),
                'SupportedMimeTypes': dbus.Array([], 's'),
                'CanQuit': False,
                'CanRaise': False,
                'HasTrackList': False,
            }[prop]
        if iface == IFACE_PLAYER:
            return {
                'PlaybackStatus': self._status,
                'LoopStatus': 'None',
                'Rate': 1.0,
                'Shuffle': False,
                'Metadata': self._metadata(),
                'Volume': 1.0,
                'Position': dbus.Int64(0),
                'MinimumRate': 1.0,
                'MaximumRate': 1.0,
                'CanGoNext': False,
                'CanGoPrevious': False,
                'CanPlay': False,
                'CanPause': False,
                'CanSeek': False,
                'CanControl': False,
            }[prop]
        raise dbus.DBusException(
            'org.freedesktop.DBus.Error.InvalidArgs',
            f'Unknown prop {prop} on {iface}')

    @dbus.service.method(dbus.PROPERTIES_IFACE,
                         in_signature='s', out_signature='a{sv}')
    def GetAll(self, iface):
        if iface == IFACE_MPRIS:
            return {
                'Identity': 'Stremio',
                'DesktopEntry': 'com.stremio.Stremio',
                'SupportedUriSchemes': dbus.Array([], 's'),
                'SupportedMimeTypes': dbus.Array([], 's'),
                'CanQuit': False,
                'CanRaise': False,
                'HasTrackList': False,
            }
        if iface == IFACE_PLAYER:
            return {
                'PlaybackStatus': self._status,
                'LoopStatus': 'None',
                'Rate': 1.0,
                'Shuffle': False,
                'Metadata': self._metadata(),
                'Volume': 1.0,
                'Position': dbus.Int64(0),
                'MinimumRate': 1.0,
                'MaximumRate': 1.0,
                'CanGoNext': False,
                'CanGoPrevious': False,
                'CanPlay': False,
                'CanPause': False,
                'CanSeek': False,
                'CanControl': False,
            }
        raise dbus.DBusException(
            'org.freedesktop.DBus.Error.InvalidArgs',
            f'Unknown interface {iface}')

    # ── MPRIS methods (no-ops) ────────────────────────────

    @dbus.service.method(IFACE_MPRIS, in_signature='', out_signature='')
    def Raise(self): pass

    @dbus.service.method(IFACE_MPRIS, in_signature='', out_signature='')
    def Quit(self): pass

    @dbus.service.method(IFACE_PLAYER, in_signature='', out_signature='')
    def Next(self): pass

    @dbus.service.method(IFACE_PLAYER, in_signature='', out_signature='')
    def Previous(self): pass

    @dbus.service.method(IFACE_PLAYER, in_signature='', out_signature='')
    def Pause(self): pass

    @dbus.service.method(IFACE_PLAYER, in_signature='', out_signature='')
    def PlayPause(self): pass

    @dbus.service.method(IFACE_PLAYER, in_signature='', out_signature='')
    def Stop(self): pass

    @dbus.service.method(IFACE_PLAYER, in_signature='', out_signature='')
    def Play(self): pass

    @dbus.service.method(IFACE_PLAYER, in_signature='x', out_signature='')
    def Seek(self, offset): pass

    @dbus.service.method(IFACE_PLAYER, in_signature='ox', out_signature='')
    def SetPosition(self, track_id, pos): pass

    @dbus.service.method(IFACE_PLAYER, in_signature='s', out_signature='')
    def OpenUri(self, uri): pass

    @dbus.service.signal(dbus.PROPERTIES_IFACE, signature='sa{sv}as')
    def PropertiesChanged(self, iface, changed, invalidated):
        pass


# ── Main ─────────────────────────────────────────────────


def run_poller(player: StremioPlayer):
    """Poll PulseAudio every 1s, update player state."""
    while True:
        try:
            out = subprocess.check_output(
                ['pactl', 'list', 'sink-inputs'],
                stderr=subprocess.DEVNULL, timeout=3,
            ).decode('utf-8', errors='replace')
        except FileNotFoundError:
            break
        except Exception:
            time.sleep(1)
            continue

        streams = parse_sink_inputs(out)

        # Check if Stremio process is alive
        stremio_running = False
        try:
            subprocess.check_output(['pgrep', '-x', 'stremio'],
                                    stderr=subprocess.DEVNULL)
            stremio_running = True
        except Exception:
            pass

        match = None
        for s in streams:
            app = s.get('application.name', '').lower()
            node = s.get('node.name', '').lower()
            binary = s.get('application.process.binary', '').lower()
            if 'stremio' in app or 'stremio' in binary:
                match = s
                break
            if stremio_running and ('mpv' in app or 'mpv' in node):
                match = s
                break

        if match:
            raw = match.get('media.name', '')
            title = re.sub(r'^Stremio:\s*', '', raw).strip()
            title = re.sub(r'\s*-\s*mpv$', '', title).strip()
            if len(title) > 80:
                title = title[:77] + '...'
            player.set_playing(title)
        else:
            player.set_stopped()

        time.sleep(1)


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    bus.request_name(BUS_NAME,
                     dbus.bus.NAME_FLAG_REPLACE_EXISTING |
                     dbus.bus.NAME_FLAG_DO_NOT_QUEUE)

    player = StremioPlayer(bus)
    print(f'Registered {BUS_NAME}', flush=True)

    # Run poller in daemon thread
    poller = threading.Thread(target=run_poller, args=(player,),
                              daemon=True)
    poller.start()

    # Block until signal
    stop = threading.Event()
    signal.signal(signal.SIGINT, lambda *_: stop.set())
    signal.signal(signal.SIGTERM, lambda *_: stop.set())
    stop.wait()


if __name__ == '__main__':
    main()
