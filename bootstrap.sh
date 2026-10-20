#!/usr/bin/env bash
# Bootstrap packages, stow configs, and fisher plugins for these dotfiles.
# Arch Linux only. Run as a normal user; sudo is used only for pacman and
# the /etc/traefik stow target.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Package lists (verified against pacman/paru sync databases)
# ---------------------------------------------------------------------------

ESSENTIAL_REPO=(
  base-devel git stow cmake curl jq
  fish tmux neovim fzf fd ripgrep bat eza zoxide btop fastfetch
)
ESSENTIAL_AUR=()

OPTIONAL_REPO=(
  # Hyprland + desktop ecosystem
  hyprland swaybg waybar swaync qt6-wayland
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
  grim slurp wl-clipboard nwg-look nwg-displays
  # Terminals / multiplexers
  kitty ghostty alacritty wezterm zellij
  # Notifications (dunst = fallback)
  dunst
  # Media / files
  mpv mpv-mpris yazi gitui lazygit
  # Dev / containers
  go php nodejs docker docker-compose traefik
  # Input / audio
  fcitx5 fcitx5-gtk fcitx5-qt wireplumber
  # Theming
  gtk3 gtk4 qt6ct
)
OPTIONAL_AUR=(
  sesh-bin webtorrent-cli stremio
)

FISHER_PLUGINS=(
  patrickf1/fzf.fish
  ilancosman/tide@v6
  jorgebucaran/autopair.fish
  meaningful-ooo/sponge
)

# Stow groups (mirrors README Installation section).
STOW_GROUPS=(
  "fish hypr waybar rofi swaync"          # core desktop
  "kitty ghostty tmux nvim yazi gitui"    # terminal + dev
  "gtk-3.0 gtk-4.0 qt6ct"                 # theming
  "portainer"                             # containers
)
# docker-config is not a stow package: stowing it would create ~/base.
# It is a setup script reached via the docker-setup alias instead.

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------

PROFILE=""
DRY_RUN=0
ASSUME_YES=0
NO_STOW=0
NO_FISHER=0

repo_installed=0 repo_skipped=0 repo_failed=0
aur_installed=0 aur_skipped=0 aur_failed=0
stow_applied=0 stow_skipped=0 stow_failed=0
fisher_installed=0 fisher_skipped=0 fisher_failed=0

REPO_PKGS=()
AUR_PKGS=()
MISSING_PKGS=()

AUR_HELPER=""

# ---------------------------------------------------------------------------
# Output helpers (colors only on a TTY)
# ---------------------------------------------------------------------------

if [ -t 1 ]; then
  C_BOLD=$'\e[1m' C_BLUE=$'\e[34m' C_YELLOW=$'\e[33m'
  C_RED=$'\e[31m' C_GREEN=$'\e[32m' C_CYAN=$'\e[36m' C_RESET=$'\e[0m'
else
  C_BOLD='' C_BLUE='' C_YELLOW='' C_RED='' C_GREEN='' C_CYAN='' C_RESET=''
fi

section() { printf '%s==> %s%s\n' "${C_BLUE}${C_BOLD}" "$*" "${C_RESET}"; }
info()    { printf '    %s\n' "$*"; }
warn()    { printf '%sWARN:%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()     { printf '%sERROR:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }

# Print the command in dry-run mode (shell-quoted args), else execute it.
run_cmd() {
  if [ "$DRY_RUN" -eq 1 ]; then
    local out="" a
    for a in "$@"; do
      out+="${out:+ }$(printf '%q' "$a")"
    done
    printf '%s[dry-run]%s %s\n' "$C_CYAN" "$C_RESET" "$out"
    return 0
  fi
  "$@"
}

usage() {
  cat <<EOF
Usage: ${0##*/} [PROFILE] [OPTIONS]

Bootstrap an Arch Linux system with the packages, stowed configs, and fish
plugins used by this dotfiles repo.

Profiles (default: --essential when none given):
  --essential     Base CLI tooling: shell, editor, core utilities (default)
  --optional      Optional desktop/dev layer only (no essential packages)
  --all           Essential + optional layers

Options:
  --dry-run       Print every action, run nothing (no sudo, no stow,
                  no fisher, no network)
  -y, --yes       Non-interactive: pass --noconfirm to package installs
  --no-stow       Skip the stow stage
  --no-fisher     Skip the fisher stage
  -h, --help      Show this help and exit

Exit codes: 0 ok, 1 runtime error or failed install step, 2 bad usage.

Notes:
  * AUR packages need paru or yay; without one they are skipped with a warning.
  * "traefik" is stowed into /etc/traefik only under --all (needs the dir).
  * lerd is never installed automatically; a manual note is printed instead.
  * A real run exits 1 when stow or sudo is missing; --dry-run only warns
    about missing binaries and keeps exiting 0.
EOF
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --essential) PROFILE="essential" ;;
      --optional)  PROFILE="optional" ;;
      --all)       PROFILE="all" ;;
      --dry-run)   DRY_RUN=1 ;;
      -y|--yes)    ASSUME_YES=1 ;;
      --no-stow)   NO_STOW=1 ;;
      --no-fisher) NO_FISHER=1 ;;
      -h|--help)   usage; exit 0 ;;
      *)
        err "unknown flag: $1"
        usage >&2
        exit 2
        ;;
    esac
    shift
  done
  if [ -z "$PROFILE" ]; then
    PROFILE="essential"
  fi
}

require_arch() {
  if ! command -v pacman >/dev/null 2>&1; then
    err "pacman not found -- this script supports Arch Linux only."
    exit 1
  fi
}

# Check required binaries up front. A real run fails hard; --dry-run only warns
# (it never executes anything, so missing binaries are informational).
preflight() {
  if [ "$NO_STOW" -eq 0 ] && ! command -v stow >/dev/null 2>&1; then
    if [ "$DRY_RUN" -eq 1 ]; then
      warn "stow not found (install the 'stow' package, or pass --no-stow); the stow stage would fail"
    else
      err "stow not found (install the 'stow' package, or pass --no-stow)"
      exit 1
    fi
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    if [ "$DRY_RUN" -eq 1 ]; then
      warn "sudo not found (needed to install packages and stow into /etc/traefik)"
    else
      err "sudo not found; required to install packages and stow into /etc/traefik"
      exit 1
    fi
  fi
}

detect_aur_helper() {
  if command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
  elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
  fi
}

assemble_packages() {
  local repo=() aur=()
  case "$PROFILE" in
    essential)
      repo=("${ESSENTIAL_REPO[@]}")
      aur=("${ESSENTIAL_AUR[@]}")
      ;;
    optional)
      repo=("${OPTIONAL_REPO[@]}")
      aur=("${OPTIONAL_AUR[@]}")
      ;;
    all)
      repo=("${ESSENTIAL_REPO[@]}" "${OPTIONAL_REPO[@]}")
      aur=("${ESSENTIAL_AUR[@]}" "${OPTIONAL_AUR[@]}")
      ;;
  esac
  REPO_PKGS=("${repo[@]+"${repo[@]}"}")
  AUR_PKGS=("${aur[@]+"${aur[@]}"}")
}

# ---------------------------------------------------------------------------
# Package stages
# ---------------------------------------------------------------------------

# True when $1 is an installed package, or a group (e.g. base-devel on
# systems where it is a group) whose every member is installed. A
# partially-installed group counts as missing.
pkg_installed() {
  local pkg="$1" members member
  if pacman -Q "$pkg" >/dev/null 2>&1; then
    return 0
  fi
  if ! members="$(pacman -Sg "$pkg" 2>/dev/null)" || [ -z "$members" ]; then
    return 1
  fi
  # pacman -Sg prints one "<group> <member>" line per group member.
  while read -r _ member; do
    [ -n "$member" ] || continue
    if ! pacman -Q "$member" >/dev/null 2>&1; then
      return 1
    fi
  done <<<"$members"
  return 0
}

# Fill global MISSING_PKGS with packages from "$@" not yet installed.
compute_missing() {
  MISSING_PKGS=()
  local pkg
  for pkg in "$@"; do
    if pkg_installed "$pkg"; then
      repo_skipped=$((repo_skipped + 1))
      info "already installed, skipping: $pkg"
    else
      MISSING_PKGS+=("$pkg")
    fi
  done
}

stage_repo_packages() {
  section "Packages (official repos, profile: $PROFILE)"
  compute_missing "${REPO_PKGS[@]+"${REPO_PKGS[@]}"}"
  local -a missing=("${MISSING_PKGS[@]+"${MISSING_PKGS[@]}"}")
  if [ "${#missing[@]}" -eq 0 ]; then
    info "all repo packages already installed"
    return 0
  fi
  local -a yes_flag=()
  if [ "$ASSUME_YES" -eq 1 ]; then
    yes_flag=(--noconfirm)
  fi
  info "installing ${#missing[@]} package(s): ${missing[*]}"
  if run_cmd sudo pacman -S --needed "${yes_flag[@]+"${yes_flag[@]}"}" "${missing[@]}"; then
    repo_installed=$((repo_installed + ${#missing[@]}))
  else
    repo_failed=$((repo_failed + ${#missing[@]}))
    warn "pacman install failed"
  fi
}

stage_aur_packages() {
  if [ "${#AUR_PKGS[@]}" -eq 0 ]; then
    return 0
  fi
  section "Packages (AUR)"
  if [ -z "$AUR_HELPER" ]; then
    warn "no AUR helper found (paru/yay); skipping ${#AUR_PKGS[@]} AUR package(s): ${AUR_PKGS[*]}"
    aur_skipped=$((aur_skipped + ${#AUR_PKGS[@]}))
    return 0
  fi
  info "using AUR helper: $AUR_HELPER"
  local -a missing=()
  local pkg
  for pkg in "${AUR_PKGS[@]}"; do
    if pkg_installed "$pkg"; then
      info "already installed, skipping: $pkg"
      aur_skipped=$((aur_skipped + 1))
    else
      missing+=("$pkg")
    fi
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    info "all AUR packages already installed"
    return 0
  fi
  local -a yes_flag=()
  if [ "$ASSUME_YES" -eq 1 ]; then
    yes_flag=(--noconfirm)
  fi
  info "installing ${#missing[@]} AUR package(s): ${missing[*]}"
  if run_cmd "$AUR_HELPER" -S --needed "${yes_flag[@]+"${yes_flag[@]}"}" "${missing[@]}"; then
    aur_installed=$((aur_installed + ${#missing[@]}))
  else
    aur_failed=$((aur_failed + ${#missing[@]}))
    warn "AUR install failed"
  fi
}

# ---------------------------------------------------------------------------
# Stow stage
# ---------------------------------------------------------------------------

# True when every sampled file under repo dir $1 resolves, in ~, to the
# same canonical path (covers file symlinks and folded directory symlinks).
# A copy-deployed config resolves elsewhere and is reported as not stowed.
dir_is_stowed() {
  local dir="$1"
  local count=0 f rel target src resolved
  while IFS= read -r -d '' f; do
    rel="${f#"$REPO_DIR/$dir"/}"
    target="$HOME/$rel"
    src="$(readlink -f "$f")"
    resolved="$(readlink -f "$target" 2>/dev/null || true)"
    if [ -z "$resolved" ] || [ "$resolved" != "$src" ]; then
      return 1
    fi
    count=$((count + 1))
  done < <(find "$REPO_DIR/$dir" -type f -print0 2>/dev/null | head -z -n 5)
  # No files found -> nothing to verify -> not stowed.
  [ "$count" -gt 0 ]
}

stow_one() {
  local target="$1" dir="$2"
  local -a stow_cmd=(stow)
  if [ "$target" != "$HOME" ]; then
    stow_cmd=(sudo stow)
  fi
  if ! command -v stow >/dev/null 2>&1; then
    warn "stow not available, skipping '$dir'"
    stow_skipped=$((stow_skipped + 1))
    return 0
  fi
  if [ ! -d "$REPO_DIR/$dir" ]; then
    warn "repo dir '$dir' not found, skipping"
    stow_skipped=$((stow_skipped + 1))
    return 0
  fi
  if [ "$target" = "$HOME" ] && dir_is_stowed "$dir"; then
    info "already stowed, skipping: $dir"
    stow_skipped=$((stow_skipped + 1))
    return 0
  fi
  # Privileged targets need a working sudo; skip (do not fail) without one.
  if [ "$target" != "$HOME" ] && [ "$DRY_RUN" -eq 0 ]; then
    if ! sudo -v; then
      warn "sudo unavailable or declined; skipping stow of '$dir' into $target"
      stow_skipped=$((stow_skipped + 1))
      return 0
    fi
  fi
  # Simulate first; never clobber unmanaged files.
  if [ "$DRY_RUN" -eq 1 ]; then
    run_cmd "${stow_cmd[@]}" --dir "$REPO_DIR" -n -v -t "$target" "$dir"
    run_cmd "${stow_cmd[@]}" --dir "$REPO_DIR" -t "$target" "$dir"
    stow_applied=$((stow_applied + 1))
    return 0
  fi
  local out
  if ! out="$("${stow_cmd[@]}" --dir "$REPO_DIR" -n -v -t "$target" "$dir" 2>&1)"; then
    warn "stow conflict for '$dir', skipping (existing files left untouched)"
    printf '%s\n' "$out" >&2
    stow_skipped=$((stow_skipped + 1))
    return 0
  fi
  if run_cmd "${stow_cmd[@]}" --dir "$REPO_DIR" -t "$target" "$dir"; then
    info "stowed: $dir -> $target"
    stow_applied=$((stow_applied + 1))
  else
    warn "stow failed for '$dir'"
    stow_failed=$((stow_failed + 1))
  fi
}

stage_stow() {
  section "Stow configs"
  if [ "$NO_STOW" -eq 1 ]; then
    info "skipped (--no-stow)"
    return 0
  fi
  local group dir
  for group in "${STOW_GROUPS[@]}"; do
    for dir in $group; do
      stow_one "$HOME" "$dir"
    done
  done
  # traefik targets /etc and is opt-in via the --all profile.
  if [ "$PROFILE" != "all" ]; then
    info "traefik stow skipped (only under --all)"
  elif [ ! -d /etc/traefik ]; then
    warn "/etc/traefik not present, skipping traefik stow"
    stow_skipped=$((stow_skipped + 1))
  else
    stow_one /etc/traefik traefik
  fi
}

# ---------------------------------------------------------------------------
# Fisher stage
# ---------------------------------------------------------------------------

stage_fisher() {
  section "Fisher plugins"
  if [ "$NO_FISHER" -eq 1 ]; then
    info "skipped (--no-fisher)"
    return 0
  fi
  if ! command -v fish >/dev/null 2>&1; then
    warn "fish not found, skipping fisher stage"
    fisher_skipped=$((fisher_skipped + 1))
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    # Read-only checks; print only what would actually run.
    if ! fish -c 'type -q fisher' >/dev/null 2>&1; then
      run_cmd fish -c 'curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'
    fi
    local -a pending=()
    local listed p
    listed="$(fish -c 'fisher list' 2>/dev/null || true)"
    for p in "${FISHER_PLUGINS[@]}"; do
      grep -qxF "$p" <<<"$listed" || pending+=("$p")
    done
    if [ "${#pending[@]}" -eq 0 ]; then
      info "all fisher plugins already installed"
    else
      run_cmd fish -c "fisher install ${pending[*]}"
    fi
    return 0
  fi
  if ! fish -c 'type -q fisher' >/dev/null 2>&1; then
    info "bootstrapping fisher"
    if fish -c 'curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'; then
      fisher_installed=$((fisher_installed + 1))
    else
      warn "fisher bootstrap failed"
      fisher_failed=$((fisher_failed + 1))
      return 0
    fi
  else
    info "fisher already present"
    fisher_skipped=$((fisher_skipped + 1))
  fi
  local -a to_install=()
  local installed_plugins p
  installed_plugins="$(fish -c 'fisher list' 2>/dev/null || true)"
  for p in "${FISHER_PLUGINS[@]}"; do
    if grep -qxF "$p" <<<"$installed_plugins"; then
      info "already installed, skipping: $p"
      fisher_skipped=$((fisher_skipped + 1))
    else
      to_install+=("$p")
    fi
  done
  if [ "${#to_install[@]}" -eq 0 ]; then
    info "all fisher plugins already installed"
    return 0
  fi
  info "installing fisher plugins: ${to_install[*]}"
  if fish -c "fisher install ${to_install[*]}"; then
    fisher_installed=$((fisher_installed + ${#to_install[@]}))
  else
    warn "fisher plugin install failed"
    fisher_failed=$((fisher_failed + ${#to_install[@]}))
  fi
}

# ---------------------------------------------------------------------------
# lerd note (never run automatically)
# ---------------------------------------------------------------------------

note_lerd() {
  section "lerd"
  if command -v lerd >/dev/null 2>&1; then
    info "lerd found: 'lerd install' wires its own fish hook and is safe to re-run manually."
  else
    info "lerd not found: install it manually upstream if wanted; this script never runs it."
  fi
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_summary() {
  section "Summary"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "dry-run: nothing was installed, stowed, or downloaded"
  fi
  printf '    %-8s %8s %8s %8s\n' "stage" "installed" "skipped" "failed"
  printf '    %-8s %8d %8d %8d\n' "repo" "$repo_installed" "$repo_skipped" "$repo_failed"
  printf '    %-8s %8d %8d %8d\n' "aur" "$aur_installed" "$aur_skipped" "$aur_failed"
  printf '    %-8s %8d %8d %8d\n' "stow" "$stow_applied" "$stow_skipped" "$stow_failed"
  printf '    %-8s %8d %8d %8d\n' "fisher" "$fisher_installed" "$fisher_skipped" "$fisher_failed"
  local total_failed
  total_failed=$((repo_failed + aur_failed + stow_failed + fisher_failed))
  if [ "$total_failed" -gt 0 ]; then
    printf '%s%d step(s) failed.%s\n' "$C_RED" "$total_failed" "$C_RESET"
    return 1
  fi
  printf '%sall steps succeeded (or were skipped).%s\n' "$C_GREEN" "$C_RESET"
  return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  parse_args "$@"
  require_arch
  preflight
  detect_aur_helper
  assemble_packages

  section "Bootstrap (profile: $PROFILE)"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "dry-run mode: printing planned actions only"
  fi

  stage_repo_packages
  stage_aur_packages
  stage_stow
  stage_fisher
  note_lerd
  print_summary
}

main "$@"
