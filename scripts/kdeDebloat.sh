#!/usr/bin/env bash
# =======================================================
# KDE Plasma Debloat (Devuan/Debian)
# -------------------------------------------------------
# Removes the "kitchen sink" apps pulled in by task-kde-desktop
# / kde-standard / kde-full (games, edu suite, PIM/Akonadi stack,
# extra media apps) while leaving Plasma itself, Dolphin, Konsole,
# Kate, Okular, Gwenview, Ark, System Settings etc. untouched.
# Also disables Baloo file indexing and Akonadi background
# processes, which are the two biggest idle-resource hogs on a
# "minimal" KDE install.
#
# Nothing here is destructive to your files — only installed
# .deb packages and a couple of per-user KDE config toggles.
# =======================================================

set -uo pipefail

RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[1;33m"; CYAN="\033[0;36m"; NC="\033[0m"

log_info() { echo -e "${CYAN}[*]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; }

is_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

# Purge only the packages from the given list that are actually installed.
purge_if_installed() {
    local label="$1"; shift
    local to_purge=()
    local pkg
    for pkg in "$@"; do
        is_installed "$pkg" && to_purge+=("$pkg")
    done
    if [ "${#to_purge[@]}" -eq 0 ]; then
        log_info "$label: nothing installed, skipping."
        return 0
    fi
    log_info "$label: purging ${to_purge[*]}"
    if sudo apt-get purge -y "${to_purge[@]}"; then
        log_ok "$label removed."
    else
        log_warn "$label: some packages failed to purge (continuing)."
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

ACTUAL_USER="${SUDO_USER:-$USER}"
run_as_user() {
    if [ "$(id -un)" = "$ACTUAL_USER" ]; then
        "$@"
    else
        sudo -u "$ACTUAL_USER" "$@"
    fi
}

echo -e "${CYAN}=========================================================${NC}"
echo -e "${CYAN} KDE Plasma Debloat${NC}"
echo -e "${CYAN}=========================================================${NC}"

if ! command_exists apt-get; then
    log_err "apt-get not found — this script needs a Debian/Devuan APT system."
    exit 1
fi

log_info "Refreshing package lists..."
sudo apt-get update || { log_err "apt-get update failed, aborting."; exit 1; }

# ---------------------------------------------------------------------------
# 1. KDE Games (kdegames metapackage pulls all of these in)
# ---------------------------------------------------------------------------
if ask "Remove KDE games (kmahjongg, kpat, kmines, ksudoku, etc.)?"; then
    purge_if_installed "KDE games" \
        kmahjongg kpat kmines kollision granatier bomber bovo kajongg \
        kbreakout kdiamond ksudoku kshisen klickety palapeli picmi \
        knights kfourinline kgoldrunner kbounce ksnakeduel kspaceduel \
        kigo ktuberling lskat kubrick kreversi kblocks kapman \
        kdegames-card-data
fi

# ---------------------------------------------------------------------------
# 2. KDE Education suite (kdeedu metapackage)
# ---------------------------------------------------------------------------
if ask "Remove KDE education apps (kalzium, kstars, parley, kgeography, etc.)?"; then
    purge_if_installed "KDE education" \
        kalzium kstars parley kgeography kwordquiz kanagram khangman \
        ktouch kturtle kbruch klettres cantor rocs artikulate blinken \
        marble marble-data kig kmplot step
fi

# ---------------------------------------------------------------------------
# 3. PIM / Akonadi stack (kontact, kmail, korganizer, akregator...)
#    This is the single heaviest idle-RAM group on a default KDE install.
# ---------------------------------------------------------------------------
if ask "Remove PIM/mail suite (Kontact, KMail, KOrganizer, Akregator, Akonadi)?"; then
    purge_if_installed "PIM/Akonadi" \
        kontact kmail kmail-account-wizard korganizer kaddressbook \
        akregator kleopatra ktnef kjots knotes kalarm \
        akonadi-backend-mysql akonadi-backend-sqlite akonadi-server \
        akonadiconsole kdepim-runtime libakonadi-calendar5 \
        libakonadi-contact5 libakonadi-notes5
fi

# ---------------------------------------------------------------------------
# 4. Extra multimedia/misc apps not needed once VLC is installed separately
# ---------------------------------------------------------------------------
if ask "Remove extra bundled apps (Elisa, Kamoso, Minuet, JuK, plasma-welcome)?"; then
    purge_if_installed "Extra apps" \
        elisa kamoso minuet juk plasma-welcome khelpcenter \
        skanlite kmag kmousetool kmouth
fi

# ---------------------------------------------------------------------------
# 5. Kate, Konqueror, Dragon Player — replaced by VSCodium / Dolphin / VLC
# ---------------------------------------------------------------------------
if ask "Remove Kate, Konqueror, and Dragon Player (replaced by VSCodium/Dolphin/VLC)?"; then
    purge_if_installed "Kate/Konqueror/Dragon Player" \
        kate kate-data konqueror konqueror-data dragonplayer
fi

# ---------------------------------------------------------------------------
# 6. Cleanup orphaned dependencies
# ---------------------------------------------------------------------------
if ask "Run apt autoremove + clean to drop now-orphaned dependencies?"; then
    log_info "Running apt-get autoremove --purge..."
    sudo apt-get autoremove --purge -y || log_warn "autoremove reported issues (non-fatal)."
    log_info "Running apt-get clean..."
    sudo apt-get clean || true
    log_ok "Cleanup done."
fi

# ---------------------------------------------------------------------------
# 6. Disable Baloo file indexing (per-user, big idle CPU/disk hog)
# ---------------------------------------------------------------------------
if ask "Disable Baloo file indexing (recommended for a lean/minimal feel)?"; then
    BALOOCTL=""
    if command_exists balooctl6; then
        BALOOCTL="balooctl6"
    elif command_exists balooctl; then
        BALOOCTL="balooctl"
    fi

    if [ -n "$BALOOCTL" ]; then
        if run_as_user "$BALOOCTL" disable; then
            log_ok "Baloo indexing disabled."
        else
            log_warn "Could not disable Baloo (it may already be disabled)."
        fi
    else
        log_warn "balooctl not found, skipping (Baloo may not be installed)."
    fi
fi

# ---------------------------------------------------------------------------
# 7. Reduce Plasma animation speed slightly (snappier "minimal" feel)
#    Best-effort only — never fails the script if the config tool is missing.
# ---------------------------------------------------------------------------
if ask "Slightly reduce KDE animation speed for a snappier feel?"; then
    KWRITECONFIG=""
    if command_exists kwriteconfig6; then
        KWRITECONFIG="kwriteconfig6"
    elif command_exists kwriteconfig5; then
        KWRITECONFIG="kwriteconfig5"
    fi

    if [ -n "$KWRITECONFIG" ]; then
        if run_as_user "$KWRITECONFIG" --file kdeglobals --group KDE --key AnimationDurationFactor 0.5; then
            log_ok "Animation speed reduced (AnimationDurationFactor=0.5)."
        else
            log_warn "Could not write animation setting (non-fatal)."
        fi
    else
        log_warn "kwriteconfig not found, skipping animation tweak."
    fi
fi

echo -e "${GREEN}KDE debloat complete.${NC}"
log_warn "Log out and back in for Baloo/animation changes to fully apply everywhere."
