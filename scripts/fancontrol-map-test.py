#!/usr/bin/env python3
"""Quick fan-channel mapping test for Nuvoton NCT668x/677x motherboards.

Stops fancontrol-curve, sets each PWM channel to 100% while keeping others
low, and reports which fan RPM changed. Restart the service when done.

Run as root:
    sudo python3 ~/.dotfiles/scripts/fancontrol-map-test.py
"""

import subprocess
import sys
import time
from pathlib import Path

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
    raise RuntimeError("No Nuvoton NCT hwmon device found.")


def read_rpm(nct: Path) -> dict[str, int]:
    rpm: dict[str, int] = {}
    for f in sorted(nct.glob("fan*_input")):
        try:
            rpm[f.name.replace("_input", "")] = int(f.read_text())
        except OSError:
            pass
    return rpm


def main() -> int:
    if Path("/run/systemd/system").exists():
        print("==> Stopping fancontrol-curve service")
        subprocess.run(["systemctl", "stop", "fancontrol-curve.service"], check=False)

    nct = find_nct_hwmon()
    print(f"Found {nct}/name = {(nct / 'name').read_text().strip()}\n")

    pwm_channels = sorted(
        int(p.name.replace("pwm", ""))
        for p in nct.glob("pwm[0-9]")
        if (nct / f"pwm{p.name.replace('pwm', '')}_enable").exists()
    )

    saved: dict[int, tuple[int, int]] = {}

    # Put all channels into manual mode at a low baseline.
    print("Setting baseline: all PWMs to 30% manual...")
    for idx in pwm_channels:
        pwm = nct / f"pwm{idx}"
        en = nct / f"pwm{idx}_enable"
        try:
            saved[idx] = (int(en.read_text()), int(pwm.read_text()))
            en.write_text("1")
            pwm.write_text(str(int(255 * 30 / 100)))
        except OSError as e:
            print(f"  warn: cannot set pwm{idx}: {e}", file=sys.stderr)

    time.sleep(3)
    baseline = read_rpm(nct)

    mappings: dict[int, list[str]] = {}

    for idx in pwm_channels:
        before = read_rpm(nct)
        pwm = nct / f"pwm{idx}"
        try:
            pwm.write_text("255")
        except OSError as e:
            print(f"pwm{idx}: cannot write 100%: {e}", file=sys.stderr)
            mappings[idx] = []
            continue

        print(f"pwm{idx} -> 100%", end="", flush=True)
        time.sleep(4)
        after = read_rpm(nct)
        print("  done")

        changed = []
        for fan, rpm_after in after.items():
            rpm_before = before.get(fan, 0)
            # fan that was dead/very low and now spins, or increased > 20%
            if rpm_after > rpm_before * 1.2 + 50:
                changed.append(f"{fan} ({rpm_before} -> {rpm_after} RPM)")
        mappings[idx] = changed

        # Return to baseline before next test.
        try:
            pwm.write_text(str(int(255 * 30 / 100)))
        except OSError:
            pass
        time.sleep(2)

    # Restore original state.
    print("\nRestoring original PWM state...")
    for idx, (orig_en, orig_pwm) in saved.items():
        try:
            (nct / f"pwm{idx}").write_text(str(orig_pwm))
            (nct / f"pwm{idx}_enable").write_text(str(orig_en))
        except OSError as e:
            print(f"  warn: cannot restore pwm{idx}: {e}", file=sys.stderr)

    print("\n=== Detected mapping (best guess) ===")
    for idx in pwm_channels:
        if mappings[idx]:
            print(f"  pwm{idx} -> {', '.join(mappings[idx])}")
        else:
            print(f"  pwm{idx} -> no RPM change detected (no fan / DC fan / different channel)")

    if Path("/run/systemd/system").exists():
        print("\n==> Restarting fancontrol-curve service")
        subprocess.run(["systemctl", "start", "fancontrol-curve.service"], check=False)

    print("\nTIP: Compare the mapping above with your physical headers.")
    print("     Then edit /etc/fancontrol-curve.conf to rename/reassign channels.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
