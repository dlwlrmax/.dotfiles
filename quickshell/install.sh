#!/usr/bin/env bash
# quickshell — install all runtime dependencies + build Rust binaries
# Supports Arch Linux (pacman + AUR helpers: paru > yay > pamac)
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[x]${NC} $*"; }

# ── detect AUR helper ──────────────────────────────────────────────
AUR=""
for h in paru yay pamac; do
    if command -v "$h" &>/dev/null; then AUR="$h"; break; fi
done

# ── system packages ───────────────────────────────────────────────
# Package list lives in .config/quickshell/deps/deps.list (shared with the
# runtime missing-package notifier). check-deps.sh --list applies the same
# rules: pacman -T (provides count) and ~/.config/quickshell/deps-ignore.
CHECK_DEPS="$(dirname "$(readlink -f "$0")")/.config/quickshell/scripts/check-deps.sh"
if ! missing_list="$(bash "$CHECK_DEPS" --list)"; then
    err "Could not read the package list ($CHECK_DEPS --list failed) — aborting"
    exit 1
fi
MISSING_PKGS=()
[ -n "$missing_list" ] && mapfile -t MISSING_PKGS < <(cut -f1 <<< "$missing_list")

info "Installing system packages (deps/deps.list)..."
if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
    info "  all packages already installed"
fi
for pkg in "${MISSING_PKGS[@]}"; do
    warn "  $pkg — installing..."
    if pacman -Si "$pkg" &>/dev/null; then
        sudo pacman -S --noconfirm --needed "$pkg"
    elif [ -n "$AUR" ]; then
        "$AUR" -S --noconfirm --needed "$pkg"
    else
        err "  $pkg — not in repos and no AUR helper found (install paru/yay manually)"
    fi
done

# ── Rust toolchain ─────────────────────────────────────────────────
if command -v rustup &>/dev/null; then
    info "Rust toolchain: installing stable..."
    rustup toolchain install stable 2>/dev/null || true
    rustup default stable 2>/dev/null || true
else
    err "rustup not found — install manually: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
fi

# ── Build Rust binaries ────────────────────────────────────────────
RUST_UTILS="$(dirname "$(readlink -f "$0")")/../rust-utils"
if [ ! -d "$RUST_UTILS" ]; then
    err "rust-utils/ not found at $RUST_UTILS — skipping Rust builds"
else
    BINS=("sys-stats" "net-stats" "net-panel")
    build_failed=()
    for bin in "${BINS[@]}"; do
        if [ -f "$RUST_UTILS/$bin/Cargo.toml" ]; then
            info "Building $bin..."
            # capture status directly: a pipeline's exit code would hide cargo failures
            if ! build_log=$(cd "$RUST_UTILS/$bin" && cargo build --release 2>&1); then
                err "  $bin — cargo build FAILED (last messages):"
                printf '%s\n' "$build_log" | tail -5 >&2
                build_failed+=("$bin")
                continue
            fi
            printf '%s\n' "$build_log" | tail -1
            if [ ! -f "$RUST_UTILS/$bin/target/release/$bin" ]; then
                err "  $bin — build succeeded but target/release/$bin is missing"
                build_failed+=("$bin")
                continue
            fi
            cp "$RUST_UTILS/$bin/target/release/$bin" "$HOME/.cargo/bin/$bin"
            info "  $bin → ~/.cargo/bin/$bin"
        else
            warn "  $bin — Cargo.toml not found, skipping"
        fi
    done

    if [ ${#build_failed[@]} -gt 0 ]; then
        err "Rust build(s) failed: ${build_failed[*]} — stale binaries were NOT reinstalled"
        exit 1
    fi
fi

# ── Services ───────────────────────────────────────────────────────
info "Checking services..."

if systemctl is-active --quiet systemd-resolved; then
    info "  systemd-resolved — running"
else
    warn "  systemd-resolved — not running; enabling..."
    sudo systemctl enable --now systemd-resolved
fi

if systemctl is-active --quiet tailscaled; then
    info "  tailscaled — running"
else
    warn "  tailscaled — not running (run 'sudo tailscale up' to connect)"
fi

# ── Font cache ─────────────────────────────────────────────────────
info "Updating font cache..."
fc-cache -fv 2>/dev/null | tail -1 || true

# ── Done ───────────────────────────────────────────────────────────
echo
info "Install complete."
echo "  Rust binaries: ~/.cargo/bin/{sys-stats,net-stats,net-panel}"
echo "  QML config:    ~/.config/quickshell/"
echo ""
warn "If switching from another bar/panel, disable it first:"
echo "  hyprctl keyword general:bar off  # for Hyprland built-in bar"
echo ""
info "Start quickshell:"
echo "  quickshell --config ~/.config/quickshell/shell.qml"
echo "  (add to hyprland.conf: exec-once = quickshell --config ~/.config/quickshell/shell.qml)"
