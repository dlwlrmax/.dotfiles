use std::collections::HashMap;
use std::process::Command;
use std::sync::Mutex;
use std::time::Duration;

use zbus::blocking::{connection, Connection, Proxy};
use zbus::fdo::{RequestNameFlags, RequestNameReply};
use zbus::interface;
use zbus::zvariant::{ObjectPath, OwnedObjectPath, OwnedValue, Value};

const BUS_NAME: &str = "org.mpris.MediaPlayer2.stremio";
const OBJ_PATH: &str = "/org/mpris/MediaPlayer2";
const TRACK_PATH: &str = "/org/mpris/MediaPlayer2/stremio/track/0";
const PLR_IFACE: &str = "org.mpris.MediaPlayer2.Player";
const MPV_BUS_NAME: &str = "org.mpris.MediaPlayer2.mpv";

// ── Global state ──────────────────────────────────────────

struct State {
    title: String,
    playing: bool,
    paused: bool,
    length_us: i64,
    position_us: i64,
}

static STATE: Mutex<State> = Mutex::new(State {
    title: String::new(),
    playing: false,
    paused: false,
    length_us: 0,
    position_us: 0,
});

// ── PulseAudio polling ────────────────────────────────────

/// Strip the "Stremio: " prefix and " - mpv" suffix from a media.name value.
fn clean_media_name(raw: &str) -> String {
    if let Some(stripped) = raw.strip_prefix("Stremio: ") {
        stripped.trim().to_string()
    } else if let Some(stripped) = raw.strip_suffix(" - mpv") {
        stripped.trim().to_string()
    } else {
        raw.trim().to_string()
    }
}

/// Returns (title, paused) for the first Stremio/mpv stream found.
///
/// `Corked:` is emitted at stream level (before the `Properties:` block), so
/// the parser tracks it separately from the key=value property map.
fn poll_pulse() -> Option<(String, bool)> {
    let out = Command::new("/usr/bin/pactl")
        .args(["list", "sink-inputs"])
        .output()
        .ok()?;
    let text = String::from_utf8_lossy(&out.stdout);

    let stremio_running = Command::new("/usr/bin/pgrep")
        .args(["stremio"])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);

    let mut streams: Vec<HashMap<String, String>> = Vec::new();
    let mut current: Option<HashMap<String, String>> = None;
    let mut in_props = false;

    for line in text.lines() {
        if line.starts_with("Sink Input #") {
            if let Some(props) = current.take() {
                streams.push(props);
            }
            current = Some(HashMap::new());
            in_props = false;
        } else if let Some(ref mut props) = current {
            let s = line.trim();
            // Corked lives at stream level, outside the Properties block.
            if let Some(v) = s.strip_prefix("Corked:") {
                props.insert("Corked".into(), v.trim().to_string());
            } else if s == "Properties:" {
                in_props = true;
            } else if in_props && s.contains('=') {
                let mut parts = s.splitn(2, '=');
                let key = parts.next().unwrap_or("").trim().to_string();
                let val = parts
                    .next()
                    .unwrap_or("")
                    .trim()
                    .trim_matches('"')
                    .to_string();
                props.insert(key, val);
            } else if s.is_empty() {
                in_props = false;
            }
        }
    }
    if let Some(props) = current {
        streams.push(props);
    }

    // Scan ALL streams, pick the first one that matches Stremio/mpv
    for props in &streams {
        let app = props
            .get("application.name")
            .map(|s| s.to_lowercase())
            .unwrap_or_default();
        let node = props
            .get("node.name")
            .map(|s| s.to_lowercase())
            .unwrap_or_default();
        let binary = props
            .get("application.process.binary")
            .map(|s| s.to_lowercase())
            .unwrap_or_default();

        let is_ours = app.contains("stremio")
            || binary.contains("stremio")
            || (stremio_running && (app.contains("mpv") || node.contains("mpv")));

        if !is_ours {
            continue;
        }

        // Prefer an explicit media.title, fall back to media.name.
        let explicit = props
            .get("media.title")
            .map(|s| s.trim().to_string())
            .unwrap_or_default();
        let title = if explicit.is_empty() {
            clean_media_name(props.get("media.name").map(String::as_str).unwrap_or(""))
        } else {
            explicit
        };

        // Filter out empty/placeholder titles (mpv preload, no file loaded)
        if title.is_empty() || title.eq_ignore_ascii_case("no file") {
            continue;
        }

        let title = if title.chars().count() > 80 {
            format!("{}...", title.chars().take(77).collect::<String>())
        } else {
            title
        };

        let paused = props
            .get("Corked")
            .map(|v| v.eq_ignore_ascii_case("yes"))
            .unwrap_or(false);

        return Some((title, paused));
    }

    None
}

// ── Native mpv detection ──────────────────────────────────

fn value_as_i64(v: &OwnedValue) -> Option<i64> {
    match &**v {
        Value::I64(n) => Some(*n),
        Value::U64(n) => Some(*n as i64),
        Value::I32(n) => Some(*n as i64),
        Value::U32(n) => Some(*n as i64),
        _ => None,
    }
}

/// Snapshot of mpv's own MPRIS state, used both to decide whether we must
/// yield (status-based) and to mirror real timing when we do publish.
struct MpvSnapshot {
    /// Any mpv MPRIS name is Playing or Paused (regardless of title).
    active: bool,
    /// Real PlaybackStatus of the best mpv candidate, if any.
    status: Option<String>,
    length_us: i64,
    position_us: i64,
}

impl MpvSnapshot {
    fn none() -> Self {
        MpvSnapshot {
            active: false,
            status: None,
            length_us: 0,
            position_us: 0,
        }
    }
}

/// Inspect every `org.mpris.MediaPlayer2.mpv*` name. Errors are treated as
/// "absent" so the caller simply falls back to title-only behaviour.
fn mpv_snapshot(conn: &Connection) -> MpvSnapshot {
    let dbus = match zbus::blocking::fdo::DBusProxy::new(conn) {
        Ok(p) => p,
        Err(_) => return MpvSnapshot::none(),
    };
    let names = match dbus.list_names() {
        Ok(n) => n,
        Err(_) => return MpvSnapshot::none(),
    };

    let mut snap = MpvSnapshot::none();
    let mut best_rank = -1i32;

    for name in names {
        let n = name.as_str();
        if n != MPV_BUS_NAME && !n.starts_with("org.mpris.MediaPlayer2.mpv.") {
            continue;
        }
        let proxy = match Proxy::new(conn, n, OBJ_PATH, PLR_IFACE) {
            Ok(p) => p,
            Err(_) => continue,
        };
        let status: String = match proxy.get_property("PlaybackStatus") {
            Ok(s) => s,
            Err(_) => continue,
        };
        if status == "Playing" || status == "Paused" {
            snap.active = true;
        }
        let length = match proxy.get_property::<HashMap<String, OwnedValue>>("Metadata") {
            Ok(md) => md.get("mpris:length").and_then(value_as_i64).unwrap_or(0),
            Err(_) => 0,
        };
        let position = proxy.get_property::<i64>("Position").unwrap_or(0);

        // Rank: prefer Playing, then Paused, then anything with a length.
        let rank = match status.as_str() {
            "Playing" => 2,
            "Paused" => 1,
            _ => 0,
        } + if length > 0 { 3 } else { 0 };
        if rank > best_rank {
            best_rank = rank;
            snap.status = Some(status);
            snap.length_us = length;
            snap.position_us = position;
        }
    }

    snap
}

// ── Metadata helpers ──────────────────────────────────────

fn track_path_val() -> OwnedValue {
    let p: ObjectPath = TRACK_PATH.try_into().unwrap();
    Value::from(OwnedObjectPath::from(p))
        .try_to_owned()
        .unwrap()
}

fn build_metadata(title: &str, length_us: i64) -> HashMap<String, OwnedValue> {
    let mut m = HashMap::new();
    m.insert("mpris:trackid".into(), track_path_val());
    m.insert("mpris:length".into(), Value::from(length_us).try_to_owned().unwrap());
    m.insert("xesam:title".into(), Value::from(title.to_string()).try_to_owned().unwrap());
    m.insert("xesam:artist".into(), Value::from("Stremio".to_string()).try_to_owned().unwrap());
    m
}

// ── D-Bus interface: org.mpris.MediaPlayer2 ───────────────

struct MprisRoot;

#[interface(name = "org.mpris.MediaPlayer2")]
impl MprisRoot {
    #[zbus(property)]
    fn identity(&self) -> &str {
        "Stremio"
    }

    #[zbus(property)]
    fn desktop_entry(&self) -> &str {
        "com.stremio.Stremio"
    }

    #[zbus(property)]
    fn supported_uri_schemes(&self) -> Vec<&str> {
        vec![]
    }

    #[zbus(property)]
    fn supported_mime_types(&self) -> Vec<&str> {
        vec![]
    }

    #[zbus(property)]
    fn has_track_list(&self) -> bool {
        false
    }

    #[zbus(property)]
    fn can_quit(&self) -> bool {
        false
    }

    #[zbus(property)]
    fn can_raise(&self) -> bool {
        true
    }

    #[zbus(name = "Raise")]
    fn raise(&self) {
        // Best-effort: focus the Stremio window via Hyprland, ignore failure.
        let _ = Command::new("hyprctl")
            .args(["dispatch", "focuswindow", "class:stremio"])
            .status();
    }
}

// ── D-Bus interface: org.mpris.MediaPlayer2.Player ────────

struct MprisPlayer;

#[interface(name = "org.mpris.MediaPlayer2.Player")]
impl MprisPlayer {
    #[zbus(property)]
    fn playback_status(&self) -> String {
        match STATE.lock() {
            Ok(s) if s.paused => "Paused".into(),
            Ok(s) if s.playing => "Playing".into(),
            _ => "Stopped".into(),
        }
    }

    #[zbus(property)]
    fn metadata(&self) -> HashMap<String, OwnedValue> {
        let state = STATE.lock().unwrap_or_else(|e| e.into_inner());
        build_metadata(&state.title, state.length_us)
    }

    #[zbus(property)]
    fn can_control(&self) -> bool {
        false
    }

    #[zbus(property)]
    fn can_play(&self) -> bool {
        false
    }

    #[zbus(property)]
    fn can_pause(&self) -> bool {
        false
    }

    #[zbus(property)]
    fn can_go_next(&self) -> bool {
        false
    }

    #[zbus(property)]
    fn can_go_previous(&self) -> bool {
        false
    }

    #[zbus(property)]
    fn can_seek(&self) -> bool {
        false
    }

    #[zbus(property)]
    fn loop_status(&self) -> &str {
        "None"
    }

    #[zbus(property)]
    fn rate(&self) -> f64 {
        1.0
    }

    #[zbus(property)]
    fn shuffle(&self) -> bool {
        false
    }

    #[zbus(property)]
    fn volume(&self) -> f64 {
        1.0
    }

    #[zbus(property)]
    fn position(&self) -> i64 {
        STATE.lock().map(|s| s.position_us).unwrap_or(0)
    }

    #[zbus(property)]
    fn minimum_rate(&self) -> f64 {
        1.0
    }

    #[zbus(property)]
    fn maximum_rate(&self) -> f64 {
        1.0
    }
}

// ── Emit PropertiesChanged signal ─────────────────────────

fn emit_props(conn: &Connection, changed: Vec<(&str, OwnedValue)>) {
    let map: HashMap<&str, OwnedValue> = changed.into_iter().collect();
    let _ = conn.emit_signal(
        None::<&str>,
        OBJ_PATH,
        "org.freedesktop.DBus.Properties",
        "PropertiesChanged",
        &(PLR_IFACE, map, Vec::<&str>::new()),
    );
}

fn set_state(title: String, playing: bool, paused: bool, length_us: i64, position_us: i64) {
    let mut state = match STATE.lock() {
        Ok(s) => s,
        Err(e) => e.into_inner(),
    };
    state.title = title;
    state.playing = playing;
    state.paused = paused;
    state.length_us = length_us;
    state.position_us = position_us;
}

// ── Main ──────────────────────────────────────────────────

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Build the session connection WITHOUT requesting BUS_NAME. Objects are
    // served, but we only take the well-known name once we have real metadata.
    let conn = connection::Builder::session()?
        .serve_at(OBJ_PATH, MprisRoot)?
        .build()?;

    // Register Player interface at startup — served regardless of name ownership.
    conn.object_server().at(OBJ_PATH, MprisPlayer)?;
    eprintln!("[stremio-mpris] ready (bus name NOT owned while idle)");

    let mut name_owned = false;
    let mut prev_title = String::new();
    let mut prev_status = String::new();
    let mut prev_length: i64 = 0;
    let mut prev_position: i64 = 0;

    loop {
        let poll = poll_pulse();
        // Rule: yield by STATUS, not title. If any mpv MPRIS name is
        // Playing/Paused we stay off the bus even when its title is empty
        // (preload / stream without metadata) — no duplicate LIVE entry.
        let mpv = mpv_snapshot(&conn);

        let (title, corked_paused) = match poll {
            Some((t, p)) => (t, p),
            None => (String::new(), false),
        };
        let should_publish = !title.is_empty() && !mpv.active;

        if should_publish {
            if !name_owned {
                match conn.request_name_with_flags(BUS_NAME, RequestNameFlags::DoNotQueue.into()) {
                    Ok(RequestNameReply::PrimaryOwner) => {
                        name_owned = true;
                        eprintln!("[stremio-mpris] acquired {BUS_NAME}");
                    }
                    Ok(other) => {
                        // Another process owns/queued the name; don't claim it.
                        eprintln!("[stremio-mpris] request_name not primary: {other:?}");
                    }
                    Err(e) => eprintln!("[stremio-mpris] request_name failed: {e}"),
                }
            }

            if name_owned {
                let corked_status = if corked_paused { "Paused" } else { "Playing" };
                // Mirror mpv's real data when it actually has media loaded
                // (non-zero length) or is Playing/Paused; otherwise fall back
                // to the title-only behaviour (length 0, position 0, Corked).
                let mirror = mpv.length_us > 0
                    || matches!(mpv.status.as_deref(), Some("Playing") | Some("Paused"));
                let status = if mirror {
                    mpv.status.clone().unwrap_or_else(|| corked_status.to_string())
                } else {
                    corked_status.to_string()
                };
                let length_us = if mirror { mpv.length_us } else { 0 };
                let position_us = if mirror { mpv.position_us } else { 0 };

                set_state(title.clone(), status == "Playing", status == "Paused", length_us, position_us);

                let mut changed: Vec<(&str, OwnedValue)> = Vec::new();
                if status != prev_status {
                    changed.push((
                        "PlaybackStatus",
                        Value::from(status.clone()).try_to_owned().unwrap(),
                    ));
                }
                if title != prev_title || length_us != prev_length {
                    let meta = build_metadata(&title, length_us);
                    changed.push(("Metadata", Value::from(meta).try_to_owned().unwrap()));
                }
                if position_us != prev_position {
                    changed.push(("Position", Value::from(position_us).try_to_owned().unwrap()));
                }
                if !changed.is_empty() {
                    emit_props(&conn, changed);
                }
                if title != prev_title {
                    eprintln!("[stremio-mpris] track: {title} ({status})");
                }
                prev_title.clone_from(&title);
                prev_status.clone_from(&status);
                prev_length = length_us;
                prev_position = position_us;
            }
        } else {
            if name_owned {
                let _ = conn.release_name(BUS_NAME);
                name_owned = false;
                eprintln!("[stremio-mpris] released {BUS_NAME}");
            }
            if !prev_status.is_empty() {
                set_state(String::new(), false, false, 0, 0);
                prev_title.clear();
                prev_status.clear();
                prev_length = 0;
                prev_position = 0;
                eprintln!("[stremio-mpris] stopped");
            }
        }

        std::thread::sleep(Duration::from_secs(1));
    }
}
