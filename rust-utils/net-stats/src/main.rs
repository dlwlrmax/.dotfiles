use std::fs;
use std::time::{SystemTime, UNIX_EPOCH};

const CACHE_FILE: &str = "/tmp/quickshell-netspeed-cache";

fn human_readable(bytes_per_sec: f64) -> String {
    if bytes_per_sec >= 1_099_511_627_776.0 {
        format!("{:.1}T", bytes_per_sec / 1_099_511_627_776.0)
    } else if bytes_per_sec >= 1_073_741_824.0 {
        format!("{:.1}G", bytes_per_sec / 1_073_741_824.0)
    } else if bytes_per_sec >= 1_048_576.0 {
        format!("{:.1}M", bytes_per_sec / 1_048_576.0)
    } else {
        format!("{:.1}K", bytes_per_sec / 1024.0)
    }
}

fn get_interface() -> Option<String> {
    let dev = fs::read_to_string("/proc/net/dev").ok()?;
    let mut candidates: Vec<&str> = Vec::new();
    let mut wifi_candidate: Option<&str> = None;

    for line in dev.lines().skip(2) {
        // line: "  eth0: bytes packets errs ..."
        let colon = line.find(':')?;
        let iface = line[..colon].trim();
        // skip loopback, docker, veth, etc.
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
        {
            continue;
        }
        // check operstate
        let state_path = format!("/sys/class/net/{iface}/operstate");
        let state = fs::read_to_string(state_path).ok()?;
        if state.trim() != "up" {
            continue;
        }
        // prefer wifi
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

    let selected = wifi_candidate
        .or_else(|| candidates.first().copied())
        .unwrap_or("");
    if selected.is_empty() {
        None
    } else {
        Some(selected.to_string())
    }
}

fn read_stats(iface: &str) -> Option<(u64, u64)> {
    let dev = fs::read_to_string("/proc/net/dev").ok()?;
    for line in dev.lines().skip(2) {
        let colon = line.find(':')?;
        let name = line[..colon].trim();
        if name != iface {
            continue;
        }
        let parts: Vec<&str> = line[colon + 1..].split_whitespace().collect();
        if parts.len() >= 9 {
            let rx: u64 = parts[0].parse().ok()?;
            let tx: u64 = parts[8].parse().ok()?;
            return Some((rx, tx));
        }
    }
    None
}

fn main() {
    let iface = match get_interface() {
        Some(i) => i,
        None => {
            println!("--|--");
            return;
        }
    };

    let now_ns = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos() as u128;

    let (rx_now, tx_now) = match read_stats(&iface) {
        Some(s) => s,
        None => {
            println!("--|--");
            return;
        }
    };

    let cached = fs::read_to_string(CACHE_FILE).ok();
    if let Some(cache) = cached {
        let parts: Vec<&str> = cache.split_whitespace().collect();
        if parts.len() >= 3 {
            let rx_prev: u64 = parts[0].parse().unwrap_or(rx_now);
            let tx_prev: u64 = parts[1].parse().unwrap_or(tx_now);
            let time_prev: u128 = parts[2].parse().unwrap_or(now_ns);

            // Detect counter reset (e.g. interface re-init): report 0 for this interval.
            let rx_diff = if rx_now < rx_prev { 0 } else { rx_now - rx_prev };
            let tx_diff = if tx_now < tx_prev { 0 } else { tx_now - tx_prev };
            let dt = now_ns.saturating_sub(time_prev);
            let secs = if dt > 0 {
                dt as f64 / 1_000_000_000.0
            } else {
                1.0
            };

            let rx_speed = rx_diff as f64 / secs;
            let tx_speed = tx_diff as f64 / secs;

            let _ = fs::write(CACHE_FILE, format!("{rx_now} {tx_now} {now_ns}"));

            println!("{}|{}", human_readable(rx_speed), human_readable(tx_speed));
            return;
        }
    }

    // First run — seed cache, output zero
    let _ = fs::write(CACHE_FILE, format!("{rx_now} {tx_now} {now_ns}"));
    println!("0.0K|0.0K");
}
