use std::collections::HashMap;
use std::fs;

use serde::Serialize;

const CACHE_FILE: &str = "/tmp/quickshell-sys-stats-cache";

#[derive(Serialize)]
struct Stats {
    cpu: u64,
    ram: u64,
    swap: u64,
    gpu: u64,
    cpu_temp: u64,
}

// ── CPU ───────────────────────────────────────────────────

fn read_cpu() -> u64 {
    let stat = fs::read_to_string("/proc/stat").ok();
    let line = stat
        .as_ref()
        .and_then(|s| s.lines().next())
        .unwrap_or("");
    let parts: Vec<&str> = line.split_whitespace().collect();
    if parts.len() < 8 {
        return 0;
    }
    let user: u64 = parts[1].parse().unwrap_or(0);
    let nice: u64 = parts[2].parse().unwrap_or(0);
    let system: u64 = parts[3].parse().unwrap_or(0);
    let idle: u64 = parts[4].parse().unwrap_or(0);
    let iowait: u64 = parts[5].parse().unwrap_or(0);
    let irq: u64 = parts[6].parse().unwrap_or(0);
    let softirq: u64 = parts[7].parse().unwrap_or(0);
    let steal: u64 = parts.get(8).and_then(|s| s.parse().ok()).unwrap_or(0);

    let curr_idle = idle + iowait;
    let curr_total = user + nice + system + idle + iowait + irq + softirq + steal;

    // read cached previous values
    let prev = fs::read_to_string(CACHE_FILE).ok();
    let (prev_idle, prev_total) = prev.as_ref().and_then(|s| {
        let mut parts = s.split_whitespace();
        let p_idle = parts.next()?.parse().ok()?;
        let p_total = parts.next()?.parse().ok()?;
        Some((p_idle, p_total))
    }).unwrap_or((curr_idle, curr_total));

    // write current values for next run
    let _ = fs::write(CACHE_FILE, format!("{curr_idle} {curr_total}"));

    let delta_idle = curr_idle.saturating_sub(prev_idle);
    let delta_total = curr_total.saturating_sub(prev_total);

    if delta_total > 0 {
        100 * (delta_total - delta_idle) / delta_total
    } else {
        0
    }
}

// ── RAM + Swap ────────────────────────────────────────────

fn read_meminfo() -> (u64, u64) {
    let meminfo = fs::read_to_string("/proc/meminfo").ok();
    let text = meminfo.as_deref().unwrap_or("");
    let mut map = HashMap::new();
    for line in text.lines() {
        let mut parts = line.splitn(2, ':');
        let key = parts.next().unwrap_or("").trim();
        let val_str = parts.next().unwrap_or("").trim().trim_end_matches(" kB");
        if let Ok(val) = val_str.parse::<u64>() {
            map.insert(key, val);
        }
    }

    let total = *map.get("MemTotal").unwrap_or(&1);
    let available = *map.get("MemAvailable").unwrap_or(&0);
    let ram = if total > 0 {
        100 * (total - available) / total
    } else {
        0
    };

    let swap_total = *map.get("SwapTotal").unwrap_or(&0);
    let swap_free = *map.get("SwapFree").unwrap_or(&0);
    let swap = if swap_total > 0 {
        100 * (swap_total - swap_free) / swap_total
    } else {
        0
    };

    (ram, swap)
}

// ── GPU ───────────────────────────────────────────────────

fn read_gpu() -> u64 {
    // Find first Intel GPU with RC6 stats (card0 or card1)
    let gpu_base = |idx: u8| -> Option<String> {
        let p = format!("/sys/class/drm/card{idx}/gt/gt0/rc6_residency_ms");
        fs::metadata(&p).ok().map(|_| format!("/sys/class/drm/card{idx}/gt/gt0"))
    };
    let gt = gpu_base(0).or_else(|| gpu_base(1)).or_else(|| gpu_base(2));
    let Some(gt) = gt else { return 0 };

    let rc6_path = format!("{gt}/rc6_residency_ms");

    let r_cur: u64 = fs::read_to_string(rc6_path)
        .ok()
        .and_then(|s| s.trim().parse().ok())
        .unwrap_or(0);

    // Cache format: "rc6_residency_ms wall_nanos"
    // wall_nanos is recorded BEFORE reading to bound the interval conservatively
    let cache_path = "/tmp/quickshell-gpu-cache";

    // Read previous cache entry BEFORE overwriting
    let cache_entry = fs::read_to_string(cache_path).ok();
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos() as u64;

    // Write current values now — next run will use these as "previous"
    let _ = fs::write(cache_path, format!("{r_cur} {now}"));

    let (r_prev, time_prev) = cache_entry.as_ref().and_then(|s| {
        let mut parts = s.split_whitespace();
        let r = parts.next()?.parse().ok()?;
        let t = parts.next()?.parse().ok()?;
        Some((r, t))
    }).unwrap_or((r_cur, now));

    let elapsed_ms = now.saturating_sub(time_prev) / 1_000_000;
    let delta_rc6 = r_cur.saturating_sub(r_prev);

    if elapsed_ms == 0 {
        return 0;
    }

    let gpu = if delta_rc6 >= elapsed_ms {
        0 // fully idle
    } else {
        100 * (elapsed_ms - delta_rc6) / elapsed_ms
    };

    gpu
}

// ── CPU Temperature ──────────────────────────────────────

fn read_cpu_temp() -> u64 {
    // Scan /sys/class/hwmon/ for temp sensors labeled CPU/Package/Tctl
    let hwmon_base = "/sys/class/hwmon";
    if let Ok(entries) = fs::read_dir(hwmon_base) {
        for entry in entries.flatten() {
            let path = entry.path();
            // Read temp1_label to find CPU sensor
            let label_path = path.join("temp1_label");
            if let Ok(label) = fs::read_to_string(&label_path) {
                let label_lower = label.trim().to_lowercase();
                if label_lower.contains("cpu")
                    || label_lower.contains("package")
                    || label_lower.contains("tctl")
                    || label_lower.contains("tdie")
                    || label_lower.contains("core")
                {
                    let temp_path = path.join("temp1_input");
                    if let Ok(temp_str) = fs::read_to_string(&temp_path) {
                        if let Ok(millideg) = temp_str.trim().parse::<u64>() {
                            return millideg / 1000;
                        }
                    }
                }
            }
        }
    }

    // Fallback: try thermal_zone (x86_pkg_temp or acpitz)
    for zone in 0..5 {
        let type_path = format!("/sys/class/thermal/thermal_zone{zone}/type");
        let temp_path = format!("/sys/class/thermal/thermal_zone{zone}/temp");
        if let Ok(ttype) = fs::read_to_string(&type_path) {
            let t = ttype.trim();
            if t == "x86_pkg_temp" || t == "acpitz" {
                if let Ok(temp_str) = fs::read_to_string(&temp_path) {
                    if let Ok(millideg) = temp_str.trim().parse::<u64>() {
                        return millideg / 1000;
                    }
                }
            }
        }
    }

    0
}

// ── Main ──────────────────────────────────────────────────

fn main() {
    let cpu = read_cpu();
    let (ram, swap) = read_meminfo();
    let gpu = read_gpu();
    let cpu_temp = read_cpu_temp();

    let stats = Stats {
        cpu,
        ram,
        swap,
        gpu,
        cpu_temp,
    };

    if let Ok(json) = serde_json::to_string(&stats) {
        println!("{json}");
    }
}
