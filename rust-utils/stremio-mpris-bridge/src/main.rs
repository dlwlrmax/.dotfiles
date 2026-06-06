use std::collections::HashMap;
use std::process::Command;
use std::sync::Mutex;
use std::time::Duration;

use zbus::blocking::Connection;
use zbus::interface;
use zbus::zvariant::{ObjectPath, OwnedObjectPath, OwnedValue, Value};

const BUS_NAME: &str = "org.mpris.MediaPlayer2.stremio";
const OBJ_PATH: &str = "/org/mpris/MediaPlayer2";
const TRACK_PATH: &str = "/org/mpris/MediaPlayer2/stremio/track/0";
const PLR_IFACE: &str = "org.mpris.MediaPlayer2.Player";

// ── Global state ──────────────────────────────────────────

struct State {
    title: String,
    playing: bool,
}

static STATE: Mutex<State> = Mutex::new(State {
    title: String::new(),
    playing: false,
});

// ── PulseAudio polling ────────────────────────────────────

fn poll_pulse() -> Option<(String, String)> {
    let out = Command::new("pactl")
        .args(["list", "sink-inputs"])
        .output()
        .ok()?;
    let text = String::from_utf8_lossy(&out.stdout);

    let mut current: Option<HashMap<String, String>> = None;
    let mut in_props = false;

    for line in text.lines() {
        if line.starts_with("Sink Input #") {
            if current.is_some() {
                break;
            }
            current = Some(HashMap::new());
            in_props = false;
        } else if let Some(ref mut props) = current {
            let s = line.trim();
            if s == "Properties:" {
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

    let props = current?;

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

    let stremio_running = Command::new("pgrep")
        .args(["stremio"])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);

    let is_ours = app.contains("stremio")
        || binary.contains("stremio")
        || (stremio_running && (app.contains("mpv") || node.contains("mpv")));

    if !is_ours {
        return None;
    }

    let raw = props.get("media.name").cloned().unwrap_or_default();

    let title = if let Some(stripped) = raw.strip_prefix("Stremio: ") {
        stripped.to_string()
    } else if let Some(stripped) = raw.strip_suffix(" - mpv") {
        stripped.to_string()
    } else {
        raw.trim().to_string()
    };

    let title = if title.len() > 80 {
        format!("{}...", &title[..77])
    } else {
        title
    };

    let id = props.get("index").cloned().unwrap_or_default();
    Some((id, title))
}

// ── Metadata helpers ──────────────────────────────────────

fn track_path_val() -> OwnedValue {
    let p: ObjectPath = TRACK_PATH.try_into().unwrap();
    Value::from(OwnedObjectPath::from(p))
        .try_to_owned()
        .unwrap()
}

fn build_metadata(title: &str) -> HashMap<String, OwnedValue> {
    let mut m = HashMap::new();
    m.insert("mpris:trackid".into(), track_path_val());
    m.insert("mpris:length".into(), Value::from(0i64).try_to_owned().unwrap());
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
        false
    }
}

// ── D-Bus interface: org.mpris.MediaPlayer2.Player ────────

struct MprisPlayer;

#[interface(name = "org.mpris.MediaPlayer2.Player")]
impl MprisPlayer {
    #[zbus(property)]
    fn playback_status(&self) -> String {
        if STATE.lock().unwrap().playing {
            "Playing".into()
        } else {
            "Stopped".into()
        }
    }

    #[zbus(property)]
    fn metadata(&self) -> HashMap<String, OwnedValue> {
        let s = STATE.lock().unwrap();
        build_metadata(&s.title)
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
        0
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

// ── Main ──────────────────────────────────────────────────

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let conn = Connection::session()?;

    conn.request_name(BUS_NAME)?;
    println!("Registered {BUS_NAME}",);

    conn.object_server().at(OBJ_PATH, MprisRoot)?;
    conn.object_server().at(OBJ_PATH, MprisPlayer)?;

    let mut prev_id: Option<String> = None;

    loop {
        let result = poll_pulse();
        let this_id = result.as_ref().map(|(id, _)| id.clone());
        let mut state = STATE.lock().unwrap();

        if let Some((_, title)) = &result {
            let changed = *title != state.title || prev_id != this_id;
            state.title.clone_from(title);
            state.playing = true;
            drop(state);

            if changed {
                let meta = build_metadata(title);
                emit_props(&conn, vec![
                    ("PlaybackStatus", Value::from("Playing".to_string()).try_to_owned().unwrap()),
                    ("Metadata", Value::from(meta).try_to_owned().unwrap()),
                ]);
            }
        } else {
            let was_playing = state.playing || !state.title.is_empty() || prev_id.is_some();
            state.title.clear();
            state.playing = false;
            drop(state);

            if was_playing {
                let meta = build_metadata("");
                emit_props(&conn, vec![
                    ("PlaybackStatus", Value::from("Stopped".to_string()).try_to_owned().unwrap()),
                    ("Metadata", Value::from(meta).try_to_owned().unwrap()),
                ]);
            }
        }

        prev_id = this_id;
        std::thread::sleep(Duration::from_secs(1));
    }
}
