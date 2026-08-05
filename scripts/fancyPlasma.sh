#!/usr/bin/env bash
# =======================================================
# Fancy Plasma — theming pass inspired by a "make KDE look modern"
# YouTube walkthrough (Darkly + Ant Dark, blur, rounded corners,
# floating titlebar, KRunner centering, panel cleanup, Konsole glass)
# -------------------------------------------------------
# What this script automates, and why some things aren't automated:
#
#   AUTOMATED (built-in KWin/Plasma toggles, or a real theme built from
#   verified source — same confidence bar as every other script here):
#     - Darkly application style + color scheme + (best-effort) window
#       decoration, built from github.com/Bali10050/Darkly's own
#       documented apt package list, branch-matched to your installed
#       Plasma version.
#     - KWin's built-in Blur effect, enabled.
#     - KWin's built-in Magic Lamp minimize effect, enabled (and the
#       stock scale-based minimize effect disabled so they don't fight
#       over which one plays).
#     - KRunner centered instead of docked to the top.
#     - A "Devuan Glass" Konsole profile: bigger monospace font,
#       White on Black scheme, background blur + ~30% transparency —
#       set as your default profile.
#     - Removing the Pager and Show Desktop panel widgets (their
#       keyboard shortcuts — Ctrl+Super+Arrows and Super+D — already
#       do the same job), via Plasma's own scripting D-Bus API rather
#       than hand-editing the panel config file.
#
#   NOT AUTOMATED, printed as a manual checklist at the end instead:
#     - Ant Dark (the Plasma Style/panel theme from the video) is
#       distributed through the KDE Store, which needs the KNewStuff/
#       OCS protocol to fetch reliably — there's no plain download URL
#       to verify the way there is for Darkly's own GitHub repo, so
#       this points you at System Settings' own "Get New" dialog
#       instead of guessing at an API.
#     - Darkly's OWN transparency sliders, corner radius, and floating
#       titlebar toggle — these live inside Darkly's own settings
#       panel, not a documented KWin config key, so there's nothing
#       to verify against.
#     - "Accent color from wallpaper" — a real Plasma feature, but
#       it's driven by D-Bus calls rather than a static config key,
#       so it's a one-click toggle in System Settings rather than
#       something this script can confidently set for you.
#     - Adding the Window List panel widget, centering panel icons
#       with spacers, and a custom menu icon — all very doable by
#       hand in under a minute, but need either an exact applet ID
#       this script can't fully verify or a file path only you have
#       (your custom icon), so they're left as manual steps too.
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

ACTUAL_USER="${SUDO_USER:-$USER}"
run_as_user() {
    if [ "$(id -un)" = "$ACTUAL_USER" ]; then
        "$@"
    else
        sudo -u "$ACTUAL_USER" "$@"
    fi
}

KWRITECONFIG=""
if command_exists kwriteconfig6; then
    KWRITECONFIG="kwriteconfig6"
elif command_exists kwriteconfig5; then
    KWRITECONFIG="kwriteconfig5"
fi
kwrite_user() {
    [ -n "$KWRITECONFIG" ] && run_as_user "$KWRITECONFIG" "$@"
}

echo -e "${CYAN}=========================================================${NC}"
echo -e "${CYAN} Fancy Plasma${NC}"
echo -e "${CYAN}=========================================================${NC}"

if [ -z "$KWRITECONFIG" ]; then
    log_err "Neither kwriteconfig6 nor kwriteconfig5 found — this needs to run on an actual Plasma install."
    exit 1
fi

if ! command_exists apt-get; then
    log_err "apt-get not found — this script needs a Debian/Devuan APT system."
    exit 1
fi

log_info "Refreshing package lists..."
sudo apt-get update || { log_err "apt-get update failed, aborting."; exit 1; }

# ---------------------------------------------------------------------------
# 1. Darkly — application style, color scheme, window decoration.
#    Built from source (github.com/Bali10050/Darkly), same fetch-verify-
#    build pattern as installPhotogimp.sh: nothing here silently fails
#    into a broken half-installed state without saying so.
# ---------------------------------------------------------------------------
if ask "Build and install the Darkly theme (application style, color scheme, window decoration)?"; then
    PLASMA_VERSION=""
    if command_exists plasmashell; then
        PLASMA_VERSION=$(plasmashell --version 2>/dev/null | grep -oP '[\d]+\.[\d]+\.[\d]+' | head -1)
    fi

    if [ -n "$PLASMA_VERSION" ] && dpkg --compare-versions "$PLASMA_VERSION" lt "6.0"; then
        log_warn "Detected Plasma $PLASMA_VERSION — this script's Darkly build targets Plasma 6 (KF6) only."
        log_warn "Skipping Darkly (Plasma 5 needs a different build path this toolkit doesn't cover)."
    else
        DARKLY_BRANCH=""
        if [ -n "$PLASMA_VERSION" ] && dpkg --compare-versions "$PLASMA_VERSION" lt "6.5"; then
            DARKLY_BRANCH="Darkly-6.4"
            log_info "Detected Plasma $PLASMA_VERSION (< 6.5) — using the Darkly-6.4 compatibility branch."
        else
            log_info "Detected Plasma ${PLASMA_VERSION:-unknown} — using Darkly's main branch."
        fi

        # KF6-only dependency subset of Darkly's own documented Kubuntu/apt
        # install list (their README's "Kubuntu (25.04)" section) — the
        # KF5 packages from that list are dropped since `./install.sh QT6`
        # only needs the KF6/Qt6 side to build the widget style + the
        # KDecoration3 window decoration (Plasma 6's decoration API is
        # KF6-only regardless, so nothing is lost by skipping KF5 here).
        install_pkgs "Darkly build dependencies" \
            cmake build-essential extra-cmake-modules gettext git \
            libkdecorations3-dev qt6-base-dev \
            libkf6coreaddons-dev libkf6colorscheme-dev libkf6config-dev \
            libkf6guiaddons-dev libkf6i18n-dev libkf6iconthemes-dev \
            libkf6windowsystem-dev libkf6kcmutils-dev libkirigami-dev \
            libkf6style-dev

        WORK_DIR=$(mktemp -d)
        trap 'rm -rf "$WORK_DIR"' EXIT

        CLONE_ARGS=(--single-branch --depth=1)
        [ -n "$DARKLY_BRANCH" ] && CLONE_ARGS+=(--branch "$DARKLY_BRANCH")
        CLONE_ARGS+=(https://github.com/Bali10050/Darkly.git "$WORK_DIR/Darkly")

        log_info "Cloning Darkly..."
        if git clone "${CLONE_ARGS[@]}" >/dev/null 2>&1; then
            (
                cd "$WORK_DIR/Darkly" || exit 1
                chmod +x install.sh
                log_info "Building Darkly (this can take a few minutes)..."
                if ./install.sh QT6; then
                    exit 0
                elif sudo ./install.sh QT6; then
                    # install.sh's own install step may need root depending
                    # on its configured prefix — retried once with sudo
                    # before giving up, rather than assuming either way.
                    exit 0
                else
                    exit 1
                fi
            )
            if [ $? -eq 0 ]; then
                log_ok "Darkly built and installed."

                kwrite_user --file kdeglobals --group KDE --key widgetStyle Darkly \
                    && log_ok "Darkly set as the application style."

                if command_exists plasma-apply-colorscheme; then
                    run_as_user plasma-apply-colorscheme Darkly >/dev/null 2>&1 \
                        && log_ok "Darkly set as the color scheme."
                else
                    kwrite_user --file kdeglobals --group General --key ColorScheme Darkly
                fi

                # Best-effort — the exact plugin ID Darkly registers its
                # KDecoration3 window decoration under isn't independently
                # verifiable without a live session, so this is a good-faith
                # attempt with a clear manual fallback if it doesn't stick.
                kwrite_user --file kwinrc --group org.kde.kdecoration2 --key library org.kde.darkly
                kwrite_user --file kwinrc --group org.kde.kdecoration2 --key theme Darkly

                for RECONFIG_CMD in "qdbus6 org.kde.KWin /KWin reconfigure" "qdbus org.kde.KWin /KWin reconfigure"; do
                    # shellcheck disable=SC2086
                    if run_as_user $RECONFIG_CMD >/dev/null 2>&1; then
                        break
                    fi
                done

                log_warn "Window decoration: if Darkly isn't visibly applied to your titlebars, set it yourself in"
                log_warn "System Settings > Colors & Themes > Window Decorations — takes 10 seconds either way."
            else
                log_warn "Darkly build failed — check the build output above. Nothing else in this toolkit depends on it."
            fi
        else
            log_warn "Could not clone Darkly (check network/GitHub reachability) — skipping."
        fi
        trap - EXIT
        rm -rf "$WORK_DIR" 2>/dev/null
    fi
fi

# ---------------------------------------------------------------------------
# 2. KWin Blur — the built-in effect, not a third-party fork. Darkly's own
#    transparency sliders (sidebar opacity etc.) need this enabled to have
#    anything to blur.
# ---------------------------------------------------------------------------
if ask "Enable the KWin Blur effect (needed for Darkly's transparency to actually blur)?"; then
    kwrite_user --file kwinrc --group Plugins --key blurEnabled true \
        && log_ok "Blur effect enabled." \
        || log_warn "Could not write the blur setting (non-fatal)."
    log_info "Tune blur/noise strength yourself in System Settings > Desktop Effects > Blur — no documented"
    log_info "config key for those sliders to set safely from a script."
fi

# ---------------------------------------------------------------------------
# 3. Magic Lamp — built-in KWin minimize effect. Disables the stock
#    scale-based minimize effect so the two don't conflict over which
#    one actually plays (KWin allows both enabled at once but only one
#    visibly wins, and it's not consistently the one you just picked).
# ---------------------------------------------------------------------------
if ask "Enable the Magic Lamp minimize effect (and disable the stock minimize animation)?"; then
    kwrite_user --file kwinrc --group Plugins --key magiclampEnabled true \
        && log_ok "Magic Lamp enabled."
    kwrite_user --file kwinrc --group Plugins --key minimizeanimationEnabled false \
        && log_ok "Stock minimize animation disabled."
    log_info "Adjust the animation speed yourself in System Settings > Desktop Effects > Magic Lamp if you want"
    log_info "the 400-500ms feel from the video — no verified config key for that duration to set here."
fi

# ---------------------------------------------------------------------------
# 4. KRunner — center it instead of the default top-docked position.
# ---------------------------------------------------------------------------
if ask "Center KRunner instead of docking it to the top of the screen?"; then
    kwrite_user --file krunnerrc --group General --key FreeFloating true \
        && log_ok "KRunner will open centered (takes effect next login)." \
        || log_warn "Could not write the KRunner setting (non-fatal)."
fi

# ---------------------------------------------------------------------------
# 5. Konsole "Devuan Glass" profile — bigger font, White on Black scheme,
#    background blur + ~30% transparency, set as default. Self-authored
#    profile file rather than a downloaded one, so there's nothing here
#    whose contents you can't read in two seconds.
# ---------------------------------------------------------------------------
if ask "Create a 'Devuan Glass' Konsole profile (bigger font, blurred/transparent background) and set it default?"; then
    HOME_DIR=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
    KONSOLE_DIR="$HOME_DIR/.local/share/konsole"
    run_as_user mkdir -p "$KONSOLE_DIR"

    PROFILE_FILE="$KONSOLE_DIR/DevuanGlass.profile"
    run_as_user tee "$PROFILE_FILE" > /dev/null << 'EOF'
[Appearance]
ColorScheme=WhiteOnBlack
Font=Monospace,15,-1,5,50,0,0,0,0,0
Opacity=0.7
BlurBackground=true

[General]
Name=Devuan Glass
Parent=FALLBACK/
EOF
    log_ok "Devuan Glass profile written to $PROFILE_FILE"

    KONSOLERC="$HOME_DIR/.config/konsolerc"
    kwrite_user --file konsolerc --group "Desktop Entry" --key DefaultProfile "DevuanGlass.profile" \
        && log_ok "Set as the default Konsole profile."
    log_info "Existing open Konsole windows won't pick this up until you open a new tab/window."
fi

# ---------------------------------------------------------------------------
# 6. Panel cleanup — removes the Pager and Show Desktop widgets via
#    Plasma's own scripting D-Bus API (the documented, sanctioned way to
#    manipulate panels — NOT hand-editing plasma-org.kde.plasma.desktop-
#    appletsrc, which is fragile enough that this toolkit avoids it
#    entirely). Their shortcuts (Ctrl+Super+Arrows, Super+D) already do
#    the same job, so nothing is lost.
# ---------------------------------------------------------------------------
if command_exists qdbus6 || command_exists qdbus; then
    QDBUS_CMD="qdbus6"; command_exists qdbus6 || QDBUS_CMD="qdbus"
    if ask "Remove the Pager and Show Desktop panel widgets (Ctrl+Super+Arrows / Super+D already do the same job)?"; then
        SCRIPT='
var panelList = panels();
for (var i = 0; i < panelList.length; i++) {
    var w = panelList[i].widgets();
    for (var j = 0; j < w.length; j++) {
        if (w[j].type == "org.kde.plasma.pager" || w[j].type == "org.kde.plasma.showdesktop") {
            w[j].remove();
        }
    }
}
'
        if run_as_user "$QDBUS_CMD" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$SCRIPT" >/dev/null 2>&1; then
            log_ok "Pager/Show Desktop widgets removed (if they were present)."
        else
            log_warn "Could not run the panel-cleanup script — remove them by hand if you want:"
            log_warn "right-click the panel > Show Panel Configuration > hover the widget > remove."
        fi
    fi
else
    log_warn "qdbus not found — skipping panel cleanup (remove Pager/Show Desktop by hand if you'd like)."
fi

# ---------------------------------------------------------------------------
# Manual finishing touches — the honest checklist for what this script
# doesn't (and can't confidently) automate. All quick, all from the video.
# ---------------------------------------------------------------------------
echo -e "${GREEN}Fancy Plasma step complete.${NC}"
echo -e "${CYAN}A few finishing touches worth doing by hand (a couple minutes total):${NC}"
echo "  • Ant Dark plasma style: System Settings > Colors & Themes > Plasma Style > Get New > search 'Ant Dark'"
echo "  • Darkly's own transparency sliders + floating titlebar: click the pencil icon next to Darkly in"
echo "    System Settings > Colors & Themes > Application Style"
echo "  • Accent color from wallpaper: System Settings > Colors & Themes > Colors > Accent Color > From Wallpaper"
echo "  • Window List widget + centered panel icons + a custom menu icon: right-click the panel > Add Widgets /"
echo "    Show Panel Configuration — the video walks through all three in about a minute"
log_warn "Log out and back in for everything (widgetStyle, KRunner, panel changes) to fully settle."
