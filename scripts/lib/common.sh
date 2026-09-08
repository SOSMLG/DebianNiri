#!/usr/bin/env bash
# =======================================================
# common.sh — shared helpers for scripts that source it
# -------------------------------------------------------
# This file was referenced by aiOpencode.sh and devToolsExtras.sh
# (`source "$SCRIPT_DIR/../lib/common.sh"`) but never actually existed
# in the repo, so both scripts failed immediately on their `source`
# line before doing anything. This is that missing file.
#
# Every OTHER script in this toolkit defines these same helpers inline
# instead of sourcing them — that's deliberate (each script stays
# runnable standalone with zero dependency on this directory existing).
# This lib is only for the two scripts that already assumed it, not a
# refactor of the other 14 working scripts.
# =======================================================

# Guard against being sourced twice in the same shell.
[ -n "${_DEVUAN_KDE_COMMON_SH_LOADED:-}" ] && return 0
_DEVUAN_KDE_COMMON_SH_LOADED=1

RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[1;33m"; CYAN="\033[0;36m"; NC="\033[0m"

log_info() { echo -e "${CYAN}[*]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; }

log_head() {
    echo -e "${CYAN}=========================================================${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}=========================================================${NC}"
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

is_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

require_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_err "Do not run this as root."
        exit 1
    fi
}

ask() {
    local prompt="$1" default="${2:-Y}" reply
    local hint="(Y/n)"
    [ "$default" = "N" ] && hint="(y/N)"
    read -rp "$(echo -e "${YELLOW}${prompt} ${hint}: ${NC}")" reply
    reply=${reply:-$default}
    [[ "$reply" =~ ^[Yy]$ ]]
}

install_pkgs() {
    local label="$1"; shift
    local to_install=()
    local pkg
    for pkg in "$@"; do
        is_installed "$pkg" || to_install+=("$pkg")
    done
    if [ "${#to_install[@]}" -eq 0 ]; then
        log_ok "$label already installed."
        return 0
    fi
    log_info "$label: installing ${to_install[*]}"
    if sudo apt-get install -y "${to_install[@]}"; then
        log_ok "$label installed."
    else
        log_warn "$label: some packages failed to install (continuing)."
        return 1
    fi
}

# Real (non-root) user, even if this got invoked via sudo somewhere upstream.
ACTUAL_USER="${SUDO_USER:-$USER}"

run_as_user() {
    if [ "$(id -un)" = "$ACTUAL_USER" ]; then
        "$@"
    else
        sudo -u "$ACTUAL_USER" "$@"
    fi
}

# KDE ships kwriteconfig6 (Plasma 6) or kwriteconfig5 (Plasma 5) — resolve
# once here so callers don't have to repeat the detection.
KWRITECONFIG=""
if command_exists kwriteconfig6; then
    KWRITECONFIG="kwriteconfig6"
elif command_exists kwriteconfig5; then
    KWRITECONFIG="kwriteconfig5"
fi
kwrite_user() {
    [ -n "$KWRITECONFIG" ] && run_as_user "$KWRITECONFIG" "$@"
}

# Best-effort service start that works whether this is running under
# systemd, sysvinit, or OpenRC — Devuan supports all three, and none of
# them can be assumed. Checked via /run/systemd/system rather than just
# "is systemctl on PATH", since some non-systemd systems still ship a
# systemctl shim.
start_service() {
    local svc="$1"
    if command_exists systemctl && [ -d /run/systemd/system ]; then
        sudo systemctl enable --now "$svc" >/dev/null 2>&1 || true
    else
        sudo service "$svc" start >/dev/null 2>&1 || true
    fi
}
