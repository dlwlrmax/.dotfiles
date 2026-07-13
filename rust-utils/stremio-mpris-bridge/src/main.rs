use std::collections::HashMap;
use std::process::Command;
use std::sync::Mutex;
use std::time::Duration;

use zbus::blocking::{connection, Connection};
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

        let raw = props.get("media.name").cloned().unwrap_or_default();

        let title = if let Some(stripped) = raw.strip_prefix("Stremio: ") {
            stripped.to_string()
        } else if let Some(stripped) = raw.strip_suffix(" - mpv") {
            stripped.to_string()
        } else {
            raw.trim().to_string()
        };

        // Filter out empty/placeholder titles (mpv preload, no file loaded)
        if title.is_empty() || title.eq_ignore_ascii_case("no file") {
            continue;
        }

        let title = if title.len() > 80 {
            format!("{}...", &title[..77])
        } else {
            title
        };

        let id = props.get("index").cloned().unwrap_or_default();
        return Some((id, title));
    }

    None
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
        match STATE.lock() {
            Ok(s) if s.playing => "Playing".into(),
            _ => "Stopped".into(),
        }
    }

    #[zbus(property)]
    fn metadata(&self) -> HashMap<String, OwnedValue> {
        let title = STATE.lock().ok().map(|s| s.title.clone()).unwrap_or_default();
        build_metadata(&title)
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
    let conn = connection::Builder::session()?
        .name(BUS_NAME)?
        .serve_at(OBJ_PATH, MprisRoot)?
        .build()?;

    // Register Player interface at startup — keep alive always
    conn.object_server().at(OBJ_PATH, MprisPlayer)?;
    println!("Registered {BUS_NAME} — interfaces: org.mpris.MediaPlayer2, org.mpris.MediaPlayer2.Player");

    let mut prev_id: Option<String> = None;
    let mut prev_title = String::new();
    let mut prev_playing = false;

    // Emit initial Stopped state so clients see the player immediately
    {
        let meta = build_metadata("");
        emit_props(&conn, vec![
            ("PlaybackStatus", Value::from("Stopped".to_string()).try_to_owned().unwrap()),
            ("Metadata", Value::from(meta).try_to_owned().unwrap()),
        ]);
    }

    loop {
        let result = poll_pulse();
        let this_id = result.as_ref().map(|(id, _)| id.clone());
        let mut state = match STATE.lock() {
            Ok(s) => s,
            Err(e) => {
                eprintln!("[stremio-mpris] Mutex poisoned, skipping cycle: {e}");
                std::thread::sleep(Duration::from_secs(2));
                continue;
            }
        };

        if let Some((_, title)) = &result {
            let changed = *title != state.title || prev_id != this_id;
            let title_changed = *title != prev_title;
            state.title.clone_from(title);
            state.playing = true;
            drop(state);

            if changed {
                let meta = build_metadata(title);
                emit_props(&conn, vec![
                    ("PlaybackStatus", Value::from("Playing".to_string()).try_to_owned().unwrap()),
                    ("Metadata", Value::from(meta).try_to_owned().unwrap()),
                ]);
                if title_changed {
                    eprintln!("[stremio-mpris] track: {title}");
                    prev_title.clone_from(title);
                }
            }
            prev_playing = true;
        } else {
            let was_playing = state.playing || !state.title.is_empty() || prev_id.is_some();
            state.title.clear();
            state.playing = false;
            drop(state);

            if was_playing {
                // Keep Player interface alive — just signal Stopped
                let meta = build_metadata("");
                emit_props(&conn, vec![
                    ("PlaybackStatus", Value::from("Stopped".to_string()).try_to_owned().unwrap()),
                    ("Metadata", Value::from(meta).try_to_owned().unwrap()),
                ]);
                if prev_playing {
                    eprintln!("[stremio-mpris] stopped");
                    prev_playing = false;
                }
                prev_title.clear();
            }
        }

        prev_id = this_id;
        std::thread::sleep(Duration::from_secs(1));
    }
}
