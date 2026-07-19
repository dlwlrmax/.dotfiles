#!/usr/bin/env bash
# Install / configure the custom Nuvoton NCT668x/677x fan-curve daemon.
# Must be run as root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "ERROR: This script must be run as root."
  echo "Run: sudo bash $0"
  exit 1
fi

# Helper: find the first Nuvoton NCT hwmon path.
find_nct_hwmon() {
  for d in /sys/class/hwmon/hwmon*; do
    if [ -f "$d/name" ]; then
      local name
      name="$(cat "$d/name" 2>/dev/null)"
      case "$name" in
        nct6683|nct6686|nct6687|nct6775|nct6776|nct6779|\
        nct6791|nct6792|nct6793|nct6795|nct6796|nct6797|nct6798|nct6799)
          echo "$d"
          return 0
          ;;
      esac
    fi
  done
  return 1
}

# Helper: unload a module if it is loaded.
unload_if_loaded() {
  local mod="$1"
  if lsmod | grep -q "^${mod} "; then
    echo "    unloading $mod to re-apply options"
    rmmod "$mod" || true
  fi
}

# Try to load the right Nuvoton driver. ASRock B660M PG Riptide may use either
# NCT6686 (handled by nct6683) or NCT6798/99 (handled by nct6775).
install -dm755 /etc/modprobe.d /etc/modules-load.d

# Clean up any previous attempt.
rm -f /etc/modules-load.d/nct6683.conf
unload_if_loaded nct6683
unload_if_loaded nct6775

MODULE=""

# nct6683 first because it's the most likely for recent ASRock boards.
if modprobe nct6683 force=1 2>/dev/null; then
  MODULE="nct6683"
  echo "==> Loaded nct6683 (force=1)"
  if [ ! -f /etc/modprobe.d/nct6683.conf ]; then
    cat > /etc/modprobe.d/nct6683.conf <<'EOF'
# Force the nct6683 driver to attach to the ASRock NCT6686/87 Super-I/O.
# The driver still validates the chip ID.
options nct6683 force=1
EOF
  fi
  printf '%s\n' nct6683 > /etc/modules-load.d/fancontrol-curve.conf
  echo "    wrote /etc/modules-load.d/fancontrol-curve.conf"
# nct6775 covers NCT6798/99 and other Nuvoton chips used by ASRock.
elif modprobe nct6775 2>/dev/null; then
  MODULE="nct6775"
  echo "==> Loaded nct6775"
  rm -f /etc/modprobe.d/nct6683.conf
  printf '%s\n' nct6775 > /etc/modules-load.d/fancontrol-curve.conf
  echo "    wrote /etc/modules-load.d/fancontrol-curve.conf"
else
  echo
  echo "ERROR: Could not load either nct6683 or nct6775 driver."
  echo "Possible causes:"
  echo "  - The wrong kernel module is being tried (check your Super-I/O chip with sensors-detect)."
  echo "  - ACPI is claiming the Super-I/O resources. Try adding the kernel parameter:"
  echo "      acpi_enforce_resources=lax"
  echo "    then reboot and re-run this script."
  echo
  echo "You can also try:"
  echo "  sudo sensors-detect --auto"
  echo "and re-run this script afterward."
  exit 1
fi

sleep 1

NCT_PATH="$(find_nct_hwmon)" || true

if [ -z "${NCT_PATH:-}" ]; then
  echo
  echo "ERROR: The $MODULE module loaded but no NCT hwmon device appeared."
  echo "This usually means the ACPI firmware is claiming the Super-I/O resources."
  echo
  echo "Fix: add the kernel parameter   acpi_enforce_resources=lax"
  echo "     then reboot and re-run this script."
  echo
  echo "Example for GRUB:"
  echo "  sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\\1 acpi_enforce_resources=lax\"/' /etc/default/grub"
  echo "  sudo grub-mkconfig -o /boot/grub/grub.cfg"
  echo "  sudo reboot"
  exit 1
fi

NCT_NAME="$(cat "$NCT_PATH/name")"
echo "==> Found Super-I/O device: $NCT_PATH/name = $NCT_NAME"

# Test whether the PWM files are actually writable.
echo "==> Testing PWM writability"
writable=true
for i in 1 2 3 4 5; do
  pwm="$NCT_PATH/pwm$i"
  en="$NCT_PATH/pwm${i}_enable"
  [ -f "$pwm" ] || continue
  [ -f "$en" ] || continue

  # Save current state and try to write manual + a mid-range PWM value.
  orig_en="$(cat "$en")"
  orig_pwm="$(cat "$pwm")"

  if ! echo 1 > "$en" 2>/dev/null; then
    echo "    WARN: cannot enable manual mode for pwm$i (read-only?)"
    writable=false
    continue
  fi
  if ! echo 128 > "$pwm" 2>/dev/null; then
    echo "    WARN: cannot write pwm$i (read-only)"
    writable=false
  fi
  # Restore previous state.
  echo "$orig_en" > "$en" 2>/dev/null || true
  echo "$orig_pwm" > "$pwm" 2>/dev/null || true
  echo "    pwm$i: $([ "$writable" = true ] && echo writable || echo read-only)"
done

if [ "$writable" = false ]; then
  echo
  echo "ERROR: The $MODULE driver can see the chip but its PWM controls are read-only on this board."
  echo "You can try an out-of-tree driver that supports write on ASRock NCT6686/87:"
  echo "  1. sudo pacman -S dkms base-devel"
  echo "  2. git clone https://github.com/Fred78290/nct6687d.git /tmp/nct6687d"
  echo "  3. cd /tmp/nct6687d && sudo make install"
  echo "  4. Blacklist the in-tree module:"
  echo "       echo 'blacklist $MODULE' > /etc/modprobe.d/${MODULE}-blacklist.conf"
  echo "  5. Reboot and re-run this script."
  echo
  echo "Or configure your fan curves in the BIOS (Fan-Tastic Tuning) instead."
  exit 1
fi

# Install the Python daemon.
echo "==> Installing fancontrol-curve daemon"
install -Dm755 "$DOTFILES_DIR/scripts/fancontrol-curve.py" /usr/local/bin/fancontrol-curve
install -Dm644 "$DOTFILES_DIR/systemd/fancontrol-curve.service" /etc/systemd/system/fancontrol-curve.service

# Generate default config if it doesn't exist.
if [ -f /etc/fancontrol-curve.conf ]; then
  echo "    /etc/fancontrol-curve.conf already exists, leaving it"
else
  cat > /etc/fancontrol-curve.conf <<'EOF'
# Custom fan curve for CPU and case fans on Nuvoton NCT668x/677x motherboards.
# Temperatures in °C, PWM in percent (0-100).
# Edit the curves and channel names to match your build.

[global]
interval = 5
temp_source = coretemp:Package id 0

# CPU fan header
[channel1]
name = CPU_FAN1
enabled = true
min_pwm = 20
curve = 40:30,55:50,70:80,85:100

# CPU/Water Pump fan header (often used as a second CPU fan)
[channel2]
name = CPU_FAN2
enabled = true
min_pwm = 20
curve = 40:30,55:50,70:80,85:100

# Chassis fan 1
[channel3]
name = CHA_FAN1
enabled = true
min_pwm = 20
curve = 40:25,55:40,70:70,85:100

# Chassis fan 2
[channel4]
name = CHA_FAN2
enabled = true
min_pwm = 20
curve = 40:25,55:40,70:70,85:100

# Chassis fan 3
[channel5]
name = CHA_FAN3
enabled = true
min_pwm = 20
curve = 40:25,55:40,70:70,85:100
EOF
  echo "    wrote /etc/fancontrol-curve.conf"
fi

# Validate that the daemon can read the config.
if ! /usr/local/bin/fancontrol-curve --check; then
  echo "ERROR: daemon check failed"
  exit 1
fi

# Enable and start the service.
echo "==> Enabling fancontrol-curve service"
systemctl daemon-reload
systemctl enable --now fancontrol-curve.service

sleep 2
systemctl status --no-pager fancontrol-curve.service

echo
echo "==> fancontrol-curve is installed and running."
echo "    Config: /etc/fancontrol-curve.conf"
echo "    Service: systemctl status fancontrol-curve"
echo "    Logs:    journalctl -u fancontrol-curve -f"
echo
echo "TIP: If a fan doesn't change speed, the channel mapping may be wrong."
echo "     Open /etc/fancontrol-curve.conf and adjust the [channelN] entries."
echo "     Use 'sensors' to see which fan# RPM changes when you set a pwm."
