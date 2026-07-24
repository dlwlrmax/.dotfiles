use serde::Serialize;
use std::fs;
use std::process::Command;

// ── Output structs ──────────────────────────────────────────────────────────

#[derive(Serialize)]
struct InfoOutput {
    iface: String,
    ips: Vec<String>,
    dns_servers: Vec<String>,
    tailscale: TailscaleInfo,
}

#[derive(Serialize)]
struct TailscaleInfo {
    active: bool,
    exit_node: Option<String>,
    peers: Vec<TailscalePeer>,
}

#[derive(Serialize)]
struct TailscalePeer {
    name: String,
    ip: String,
    online: bool,
}

#[derive(Serialize)]
struct DnsListOutput {
    current_dns: Vec<String>,
    presets: Vec<DnsPreset>,
}

#[derive(Serialize)]
struct DnsPreset {
    name: String,
    primary: String,
    secondary: String,
}

#[derive(Serialize)]
struct DnsSetOutput {
    success: bool,
    provider: String,
    primary: String,
    secondary: String,
    error: Option<String>,
}

#[derive(Serialize)]
struct SpeedtestOutput {
    download_mbps: f64,
    upload_mbps: f64,
    ping_ms: f64,
    server_name: String,
    error: Option<String>,
}

#[derive(Serialize)]
struct ErrorOutput {
    error: String,
}

// ── Interface detection (reused from net-stats pattern) ─────────────────────

fn get_interface() -> Option<String> {
    let dev = fs::read_to_string("/proc/net/dev").ok()?;
    let mut candidates: Vec<&str> = Vec::new();
    let mut wifi_candidate: Option<&str> = None;

    for line in dev.lines().skip(2) {
        let colon = line.find(':')?;
        let iface = line[..colon].trim();

        // Skip virtual / non-physical interfaces
        if iface.starts_with("lo")
            || iface.starts_with("docker")
            || iface.starts_with("veth")
            || iface.starts_with("br-")
            || iface.starts_with("virbr")
            || iface.starts_with("tun")
            || iface.starts_with("tap")
            || iface.starts_with("wg")
            || iface.starts_with("zt")
            || iface.starts_with("dummy")
            || iface.starts_with("bond")
            || iface.starts_with("tailscale")
        {
            continue;
        }

        let state_path = format!("/sys/class/net/{iface}/operstate");
        let state = fs::read_to_string(state_path).ok()?;
        if state.trim() != "up" {
            continue;
        }

        // Prefer wifi interface
        if iface.starts_with("wlp")
            || iface.starts_with("wlan")
            || iface.starts_with("wlo")
            || iface.contains("wifi")
        {
            wifi_candidate = Some(iface);
            break;
        }
        candidates.push(iface);
    }

    wifi_candidate
        .or_else(|| candidates.first().copied())
        .map(|s| s.to_string())
}

// ── IP addresses ────────────────────────────────────────────────────────────

fn get_ips(iface: &str) -> Vec<String> {
    let output = match Command::new("ip").args(["-j", "addr", "show", iface]).output() {
        Ok(o) => o,
        Err(_) => return vec![],
    };
    if !output.status.success() {
        return vec![];
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let val: serde_json::Value = match serde_json::from_str(&stdout) {
        Ok(v) => v,
        Err(_) => return vec![],
    };

    let mut ips = Vec::new();
    if let Some(arr) = val.as_array() {
        for entry in arr {
            if let Some(addr_info) = entry.get("addr_info").and_then(|a| a.as_array()) {
                for addr in addr_info {
                    let local = addr.get("local").and_then(|l| l.as_str()).unwrap_or("");
                    let scope = addr.get("scope").and_then(|s| s.as_str()).unwrap_or("");
                    // Skip link-local addresses
                    if local.is_empty() || scope == "link" {
                        continue;
                    }
                    let prefixlen = addr
                        .get("prefixlen")
                        .and_then(|p| p.as_u64())
                        .map(|p| p.to_string())
                        .unwrap_or_default();
                    if prefixlen.is_empty() {
                        ips.push(local.to_string());
                    } else {
                        ips.push(format!("{}/{}", local, prefixlen));
                    }
                }
            }
        }
    }
    ips
}

// ── DNS servers ─────────────────────────────────────────────────────────────

fn get_dns(iface: &str) -> Vec<String> {
    let output = match Command::new("resolvectl").args(["dns", iface]).output() {
        Ok(o) => o,
        Err(_) => return vec![],
    };
    if !output.status.success() {
        return vec![];
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    // Parse "Link 2 (eth0): 1.1.1.1 8.8.8.8"
    for line in stdout.lines() {
        if let Some(colon_pos) = line.find(':') {
            let dns_part = line[colon_pos + 1..].trim();
            if !dns_part.is_empty() {
                return dns_part.split_whitespace().map(|s| s.to_string()).collect();
            }
        }
    }
    vec![]
}

// ── Tailscale status ────────────────────────────────────────────────────────

fn get_tailscale_info() -> TailscaleInfo {
    let output = match Command::new("tailscale")
        .args(["status", "--json"])
        .output()
    {
        Ok(o) => o,
        Err(_) => {
            return TailscaleInfo {
                active: false,
                exit_node: None,
                peers: vec![],
            }
        }
    };
    if !output.status.success() {
        return TailscaleInfo {
            active: false,
            exit_node: None,
            peers: vec![],
        };
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let val: serde_json::Value = match serde_json::from_str(&stdout) {
        Ok(v) => v,
        Err(_) => {
            return TailscaleInfo {
                active: false,
                exit_node: None,
                peers: vec![],
            }
        }
    };

    let active = val.get("Self").is_some();

    // Determine active exit node
    let exit_node_id = val
        .get("Self")
        .and_then(|s| s.get("ExitNodeID"))
        .and_then(|e| e.as_str())
        .unwrap_or("");

    let exit_node = if exit_node_id.is_empty() {
        None
    } else {
        val.get("Peer")
            .and_then(|p| p.get(exit_node_id))
            .and_then(|peer| peer.get("HostName"))
            .and_then(|h| h.as_str())
            .map(|s| s.to_string())
    };

    // Collect peers
    let mut peers = Vec::new();
    if let Some(peer_map) = val.get("Peer").and_then(|p| p.as_object()) {
        for (_, peer) in peer_map {
            let name = peer
                .get("HostName")
                .and_then(|h| h.as_str())
                .unwrap_or("unknown")
                .to_string();
            let ip = peer
                .get("TailscaleIPs")
                .and_then(|ips| ips.as_array())
                .and_then(|arr| arr.first())
                .and_then(|ip| ip.as_str())
                .unwrap_or("")
                .to_string();
            let online = peer
                .get("Online")
                .and_then(|o| o.as_bool())
                .unwrap_or(false);

            if !name.is_empty() {
                peers.push(TailscalePeer { name, ip, online });
            }
        }
    }

    TailscaleInfo {
        active,
        exit_node,
        peers,
    }
}

// ── DNS presets ─────────────────────────────────────────────────────────────

fn presets() -> Vec<DnsPreset> {
    vec![
        DnsPreset {
            name: "Cloudflare".into(),
            primary: "1.1.1.1".into(),
            secondary: "1.0.0.1".into(),
        },
        DnsPreset {
            name: "Google".into(),
            primary: "8.8.8.8".into(),
            secondary: "8.8.4.4".into(),
        },
        DnsPreset {
            name: "Quad9".into(),
            primary: "9.9.9.9".into(),
            secondary: "149.112.112.112".into(),
        },
        DnsPreset {
            name: "OpenDNS".into(),
            primary: "208.67.222.222".into(),
            secondary: "208.67.220.220".into(),
        },
        DnsPreset {
            name: "AdGuard".into(),
            primary: "94.140.14.14".into(),
            secondary: "94.140.15.15".into(),
        },
        DnsPreset {
            name: "NextDNS".into(),
            primary: "45.90.28.0".into(),
            secondary: "45.90.30.0".into(),
        },
        DnsPreset {
            name: "Mullvad".into(),
            primary: "194.242.2.2".into(),
            secondary: "194.242.2.3".into(),
        },
    ]
}

// ── Subcommand: info ────────────────────────────────────────────────────────

fn cmd_info() {
    let iface = get_interface().unwrap_or_default();
    let ips = get_ips(&iface);
    let dns_servers = get_dns(&iface);
    let tailscale = get_tailscale_info();

    let output = InfoOutput {
        iface,
        ips,
        dns_servers,
        tailscale,
    };
    println!("{}", serde_json::to_string(&output).unwrap_or_default());
}

// ── Subcommand: dns list ────────────────────────────────────────────────────

fn cmd_dns_list() {
    let iface = get_interface().unwrap_or_default();
    let current_dns = get_dns(&iface);

    let output = DnsListOutput {
        current_dns,
        presets: presets(),
    };
    println!("{}", serde_json::to_string(&output).unwrap_or_default());
}

// ── Subcommand: dns set ─────────────────────────────────────────────────────

fn cmd_dns_set(provider_name: &str) {
    let preset = presets()
        .into_iter()
        .find(|p| p.name.to_lowercase() == provider_name.to_lowercase());

    let (name, primary, secondary) = match preset {
        Some(p) => (p.name, p.primary, p.secondary),
        None => {
            let output = DnsSetOutput {
                success: false,
                provider: provider_name.to_string(),
                primary: String::new(),
                secondary: String::new(),
                error: Some(format!("Unknown provider: {}", provider_name)),
            };
            println!("{}", serde_json::to_string(&output).unwrap_or_default());
            return;
        }
    };

    let iface = match get_interface() {
        Some(i) => i,
        None => {
            let output = DnsSetOutput {
                success: false,
                provider: name,
                primary: primary.clone(),
                secondary: secondary.clone(),
                error: Some("No active interface found".into()),
            };
            println!("{}", serde_json::to_string(&output).unwrap_or_default());
            return;
        }
    };

    let result = Command::new("resolvectl")
        .args(["dns", &iface, &primary, &secondary])
        .output();

    match result {
        Ok(o) if o.status.success() => {
            let output = DnsSetOutput {
                success: true,
                provider: name,
                primary,
                secondary,
                error: None,
            };
            println!("{}", serde_json::to_string(&output).unwrap_or_default());
        }
        Ok(o) => {
            let stderr = String::from_utf8_lossy(&o.stderr).trim().to_string();
            let output = DnsSetOutput {
                success: false,
                provider: name,
                primary,
                secondary,
                error: Some(if stderr.is_empty() {
                    format!("resolvectl exited with code {}", o.status.code().unwrap_or(-1))
                } else {
                    stderr
                }),
            };
            println!("{}", serde_json::to_string(&output).unwrap_or_default());
        }
        Err(e) => {
            let output = DnsSetOutput {
                success: false,
                provider: name,
                primary,
                secondary,
                error: Some(format!("Failed to run resolvectl: {}", e)),
            };
            println!("{}", serde_json::to_string(&output).unwrap_or_default());
        }
    }
}

// ── Subcommand: speedtest ───────────────────────────────────────────────────

fn cmd_speedtest() {
    // Try multiple speedtest binaries/flags in order:
    //   1. speedtest-cli --json   (legacy Python version)
    //   2. speedtest --json        (some installations)
    //   3. speedtest --format=json (Ookla CLI)
    let attempts: [(&str, &[&str]); 3] = [
        ("speedtest-cli", &["--json"]),
        ("speedtest", &["--json"]),
        ("speedtest", &["--format=json"]),
    ];

    for (bin, args) in &attempts {
        if let Ok(output) = Command::new(bin).args(*args).output() {
            if output.status.success() {
                let stdout = String::from_utf8_lossy(&output.stdout).to_string();
                print_speedtest_result(&stdout);
                return;
            }
        }
    }

    // All attempts failed
    let result = SpeedtestOutput {
        download_mbps: 0.0,
        upload_mbps: 0.0,
        ping_ms: 0.0,
        server_name: String::new(),
        error: Some("speedtest-cli or speedtest not found or failed".into()),
    };
    println!("{}", serde_json::to_string(&result).unwrap_or_default());
}

fn print_speedtest_result(raw_json: &str) {
    let val: serde_json::Value = match serde_json::from_str(raw_json) {
        Ok(v) => v,
        Err(_) => {
            let result = SpeedtestOutput {
                download_mbps: 0.0,
                upload_mbps: 0.0,
                ping_ms: 0.0,
                server_name: String::new(),
                error: Some("Failed to parse speedtest output".into()),
            };
            println!("{}", serde_json::to_string(&result).unwrap_or_default());
            return;
        }
    };

    // Detect format: Ookla CLI uses download.bandwidth (bytes/sec),
    // legacy Python speedtest-cli uses download (bits/sec) directly
    let is_ookla = val
        .get("download")
        .and_then(|d| d.get("bandwidth"))
        .is_some();

    let download_raw: f64 = if is_ookla {
        val.get("download")
            .and_then(|d| d.get("bandwidth"))
            .and_then(|b| b.as_f64())
            .unwrap_or(0.0)
    } else {
        val.get("download")
            .and_then(|d| d.as_f64())
            .unwrap_or(0.0)
    };

    let upload_raw: f64 = if is_ookla {
        val.get("upload")
            .and_then(|u| u.get("bandwidth"))
            .and_then(|b| b.as_f64())
            .unwrap_or(0.0)
    } else {
        val.get("upload")
            .and_then(|u| u.as_f64())
            .unwrap_or(0.0)
    };

    // Ookla reports bytes/sec → multiply by 8, then divide by 1M
    // Legacy reports bits/sec → divide by 1M
    let download_mbps = if is_ookla {
        download_raw * 8.0 / 1_000_000.0
    } else {
        download_raw / 1_000_000.0
    };
    let upload_mbps = if is_ookla {
        upload_raw * 8.0 / 1_000_000.0
    } else {
        upload_raw / 1_000_000.0
    };

    let ping_ms = val
        .get("ping")
        .and_then(|p| p.get("latency"))
        .and_then(|l| l.as_f64())
        .or_else(|| val.get("ping").and_then(|p| p.as_f64()))
        .unwrap_or(0.0);

    let server_name = val
        .get("server")
        .and_then(|s| s.get("name"))
        .and_then(|n| n.as_str())
        .unwrap_or("")
        .to_string();

    let result = SpeedtestOutput {
        download_mbps: (download_mbps * 100.0).round() / 100.0,
        upload_mbps: (upload_mbps * 100.0).round() / 100.0,
        ping_ms: (ping_ms * 100.0).round() / 100.0,
        server_name,
        error: None,
    };
    println!("{}", serde_json::to_string(&result).unwrap_or_default());
}

// ── Helpers ─────────────────────────────────────────────────────────────────

fn print_json_error(msg: &str) {
    let err = ErrorOutput {
        error: msg.to_string(),
    };
    println!("{}", serde_json::to_string(&err).unwrap_or_default());
}

// ── Main dispatch ───────────────────────────────────────────────────────────

fn main() {
    let args: Vec<String> = std::env::args().collect();

    match args.get(1).map(|s| s.as_str()) {
        Some("info") => cmd_info(),
        Some("dns") => match args.get(2).map(|s| s.as_str()) {
            Some("list") => cmd_dns_list(),
            Some("set") => {
                if let Some(name) = args.get(3) {
                    cmd_dns_set(name);
                } else {
                    print_json_error("Usage: net-panel dns set <name>");
                }
            }
            Some(other) => {
                print_json_error(&format!("Unknown dns subcommand: {}", other));
            }
            None => {
                print_json_error("Usage: net-panel dns [list|set <name>]");
            }
        },
        Some("speedtest") => cmd_speedtest(),
        Some(other) => {
            print_json_error(&format!("Unknown command: {}", other));
        }
        None => {
            print_json_error("Usage: net-panel [info|dns|speedtest]");
        }
    }
}
