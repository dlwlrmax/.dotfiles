#!/usr/bin/env python3
"""Simple user-space fan-curve daemon for Nuvoton NCT668x/677x motherboards.

Configuration: /etc/fancontrol-curve.conf (INI)
"""

import argparse
import configparser
import signal
import sys
import time
from pathlib import Path

DEFAULT_CONFIG = "/etc/fancontrol-curve.conf"

# nct6683 module exposes nct6683/6/7; nct6775 module exposes nct6775/6/8/9 etc.
NCT_NAMES = (
    "nct6683", "nct6686", "nct6687",
    "nct6775", "nct6776", "nct6779",
    "nct6791", "nct6792", "nct6793", "nct6795", "nct6796", "nct6797", "nct6798", "nct6799",
)


def find_hwmon(name: str) -> Path | None:
    for p in Path("/sys/class/hwmon").glob("hwmon*"):
        try:
            if (p / "name").read_text().strip() == name:
                return p
        except OSError:
            pass
    return None


def find_nct_hwmon() -> Path:
    for name in NCT_NAMES:
        h = find_hwmon(name)
        if h:
            return h
    raise RuntimeError(
        "No Nuvoton NCT668x/677x hwmon device found. "
        "Load the nct6683 or nct6775 module first."
    )


def find_temp_source(spec: str) -> Path:
    """spec: 'chip:label', e.g. 'coretemp:Package id 0' or 'nct6686:CPUTIN'."""
    chip, label = spec.split(":", 1)
    hwmon = find_hwmon(chip)
    if not hwmon:
        raise RuntimeError(f"hwmon chip {chip!r} not found")
    for label_path in sorted(hwmon.glob("temp*_label")):
        try:
            if label_path.read_text().strip() == label:
                return hwmon / label_path.name.replace("_label", "_input")
        except OSError:
            pass
    raise RuntimeError(f"temperature label {label!r} not found on {chip}")


def read_temp(path: Path) -> float | None:
    try:
        return int(path.read_text()) / 1000.0
    except OSError:
        return None


def pwm_from_curve(temp: float, curve: list[tuple[float, float]]) -> float:
    if temp <= curve[0][0]:
        return curve[0][1]
    if temp >= curve[-1][0]:
        return curve[-1][1]
    for i in range(len(curve) - 1):
        t0, p0 = curve[i]
        t1, p1 = curve[i + 1]
        if t0 <= temp <= t1:
            frac = (temp - t0) / (t1 - t0)
            return p0 + frac * (p1 - p0)
    return curve[-1][1]


def set_pwm(nct: Path, idx: int, percent: int, saved_enable: dict) -> None:
    pwm_path = nct / f"pwm{idx}"
    enable_path = nct / f"pwm{idx}_enable"
    if not pwm_path.exists():
        return

    # Switch to manual mode, remembering the original mode so we can restore it.
    try:
        if enable_path.exists():
            if idx not in saved_enable:
                saved_enable[idx] = int(enable_path.read_text())
            if saved_enable[idx] != 1:
                enable_path.write_text("1")
    except OSError as e:
        raise RuntimeError(f"cannot set {enable_path} to manual: {e}")

    pwm_val = max(0, min(255, int(255 * percent / 100)))
    try:
        pwm_path.write_text(str(pwm_val))
    except OSError as e:
        raise RuntimeError(f"cannot write {pwm_path}: {e}")


def restore_auto(nct: Path, saved_enable: dict) -> None:
    for idx, orig in saved_enable.items():
        enable_path = nct / f"pwm{idx}_enable"
        if enable_path.exists():
            try:
                enable_path.write_text(str(orig))
            except OSError:
                pass


def parse_config(path: Path) -> tuple[float, Path, dict[int, dict]]:
    cp = configparser.ConfigParser()
    cp.read(path)

    if "global" not in cp:
        raise RuntimeError(f"{path}: missing [global] section")

    interval = cp["global"].getfloat("interval", 5.0)
    temp_source = cp["global"].get("temp_source", "coretemp:Package id 0")
    temp_path = find_temp_source(temp_source)

    channels: dict[int, dict] = {}
    for section in cp.sections():
        if not section.startswith("channel"):
            continue
        idx = int(section.replace("channel", ""))
        curve_str = cp[section].get("curve", "40:30,60:50,70:80,80:100")
        curve = []
        for point in curve_str.split(","):
            t, p = point.split(":")
            curve.append((float(t.strip()), float(p.strip())))
        curve.sort(key=lambda x: x[0])

        channels[idx] = {
            "name": cp[section].get("name", f"fan{idx}"),
            "enabled": cp[section].getboolean("enabled", True),
            "curve": curve,
            "min_pwm": cp[section].getint("min_pwm", 0),
        }

    return interval, temp_path, channels


def main() -> int:
    parser = argparse.ArgumentParser(description="Custom fan-curve daemon")
    parser.add_argument("-c", "--config", default=DEFAULT_CONFIG)
    parser.add_argument("-d", "--dry-run", action="store_true")
    parser.add_argument("--check", action="store_true", help="verify hwmon and exit")
    args = parser.parse_args()

    try:
        nct = find_nct_hwmon()
    except RuntimeError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    if args.check:
        print(f"OK: found {nct}/name = {(nct / 'name').read_text().strip()}")
        return 0

    try:
        interval, temp_path, channels = parse_config(Path(args.config))
    except Exception as e:
        print(f"ERROR: failed to parse config: {e}", file=sys.stderr)
        return 1

    print(f"Using temperature source {temp_path}")
    print(f"Using NCT hwmon {nct}")
    print(f"Channels: {', '.join(f'{k}={v['name']}' for k, v in channels.items())}")

    saved_enable: dict[int, int] = {}
    keep_running = True

    def on_signal(signum, frame):
        nonlocal keep_running
        keep_running = False

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)

    while keep_running:
        temp = read_temp(temp_path)
        if temp is None:
            print("WARNING: failed to read temperature", file=sys.stderr)
            time.sleep(interval)
            continue

        line = f"temp={temp:.1f}C"
        for idx, cfg in sorted(channels.items()):
            if not cfg["enabled"]:
                continue
            pct = int(pwm_from_curve(temp, cfg["curve"]))
            pct = max(cfg["min_pwm"], min(100, pct))
            line += f" {cfg['name']}={pct}%"
            if not args.dry_run:
                try:
                    set_pwm(nct, idx, pct, saved_enable)
                except RuntimeError as e:
                    print(f"ERROR: {e}", file=sys.stderr)
        print(line)
        time.sleep(interval)

    restore_auto(nct, saved_enable)
    print("Restored automatic fan control.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
