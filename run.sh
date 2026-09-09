#!/usr/bin/env bash
# ==========================================
# 🧩  Devuan/Debian KDE Setup — Ordered Runner
# Runs setup scripts in the order defined below,
# asks Y/N per script with a default value.
# Same pattern as DebianSway's run.sh.
# ==========================================

set -uo pipefail
# NOTE: intentionally not using `set -e` here. Individual scripts manage
# their own error handling; one script failing should not silently abort
# every later step (you'd lose the touchpad fix because Firefox's download
# timed out, etc). Each script is still expected to exit non-zero on
# failure so this runner can report it.

# --- Colors ---
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[0;36m"
RESET="\033[0m"

# --- Directory setup ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# --- Refuse to run as root directly ---
# Per-user state (Firefox profile, ~/.bashrc, KDE configs, ~/.local/bin)
# must land in the real user's $HOME, not /root. Scripts call sudo
# themselves for the bits that need it.
if [ "$(id -u)" -eq 0 ] && [ -z "${SUDO_USER:-}" ]; then
    echo -e "${RED}Please run this as your normal user, not as root / sudo bash run.sh.${RESET}"
    echo -e "${YELLOW}Each script will call sudo itself for the parts that need it.${RESET}"
    exit 1
fi

# --- Distro check (Devuan or Debian; both ship /etc/debian_version) ---
if [ -f /etc/devuan_version ]; then
    echo -e "${GREEN}Devuan detected: $(cat /etc/devuan_version)${RESET}"
elif [ -f /etc/debian_version ]; then
    echo -e "${GREEN}Debian-based system detected: $(cat /etc/debian_version)${RESET}"
else
    echo -e "${YELLOW}Warning: this toolkit targets Devuan/Debian. Your system may not be compatible.${RESET}"
    read -r -p "Continue anyway? (y/N): " continue_anyway
    [[ "$continue_anyway" =~ ^[Yy]$ ]] || exit 1
fi

# --- Ordered list: "script|description|default" ---
SCRIPTS=(
    "addUserToGroups.sh|Add your user to input/video/render groups (needed for touchpad + GPU accel fixes)|Y"
    "kdeDebloat.sh|Debloat KDE Plasma (games/education/PIM/extras/Kate/Konqueror/Dragon Player) toward a minimal-but-functional install|Y"
    "usefulApps.sh|Install VLC, TLP (+ ThinkPad battery thresholds), and a few small KDE-completing utilities|Y"
    "catppuccinPlasma.sh|Catppuccin (Mocha, Red accent) Global Theme, icons, Konsole profile — alternative to fancyPlasma.sh's Darkly, pick one|Y"
    "bootThemeSetup.sh|Carry the Catppuccin theme to Plymouth (boot splash), GRUB, and the SDDM login screen|Y"
    "touchpadTrackpointFix.sh|Apply touchpad/trackpoint polling + libinput fixes|Y"
    "hardwareSupport.sh|Install WiFi/Bluetooth firmware, CPU microcode, and fwupd firmware updates|Y"
    "bluetoothSetup.sh|Set up the Bluetooth stack, Bluedevil, and audio bridging for headsets/earbuds|Y"
    "multimediaCodecs.sh|Install audio/video codecs + DVD playback support|Y"
    "firefoxHarden.sh|Install & harden Firefox ESR with Betterfox + privacy policies|Y"
    "installFonts.sh|Install Noto, Font Awesome, and JetBrainsMono Nerd Font|Y"
    "terminalButterbash.sh|Install ButterBash for a more functional terminal|Y"
    "fastfetchConfig.sh|Install fastfetch + curated config presets|Y"
    "desktopEssentials.sh|Set up Flatpak/Discover, PackageKit update notifications, printing, Partition Manager, and the firewall panel|Y"
    "timeshiftSetup.sh|Install Timeshift for system snapshots/restore|Y"
    "installPhotogimp.sh|(optional) Install GIMP + PhotoGIMP's Photoshop-like layout/theme|N"
    "installVscodium.sh|(optional) Install VSCodium editor|N"
    "vscodiumDevSetup.sh|(optional) Configure VSCodium for C++/Python development|N"
    "aiOpencode.sh|Install OpenCode AI coding agent + hotkey + system skill file (from ohmydebn)|Y"
    "devToolsExtras.sh|(optional) Install curated dev extras: btop, eza, bat, zoxide check, Neovim+lazy.nvim, KeePassXC|N"
    "gamingSetup.sh|(optional) Install Heroic Games Launcher / Steam / Wine|N"
    "vesktopTelegram.sh|(optional) Install Vesktop (Discord client) / Telegram|N"
)

echo -e "${BLUE}=========================================================${RESET}"
echo -e "${BLUE}   Devuan/Debian KDE Setup${RESET}"
echo -e "${BLUE}=========================================================${RESET}\n"

FAILED=()
SKIPPED=()

for ENTRY in "${SCRIPTS[@]}"; do
    SCRIPT="${ENTRY%%|*}"
    REST="${ENTRY#*|}"
    DESC="${REST%%|*}"
    DEFAULT="${REST##*|}"
    SCRIPT_PATH="$SCRIPTS_DIR/$SCRIPT"

    echo -e "${YELLOW}▶ ${SCRIPT}${RESET}"
    echo -e "   ${CYAN}${DESC}${RESET}"

    if [ ! -f "$SCRIPT_PATH" ]; then
        echo -e "${RED}   ❌ Script not found: $SCRIPT_PATH${RESET}\n"
        FAILED+=("$SCRIPT (missing)")
        continue
    fi

    DEFAULT=${DEFAULT^^}
    PROMPT="   ➤ Run this script? (y/N): "
    [ "$DEFAULT" == "Y" ] && PROMPT="   ➤ Run this script? (Y/n): "

    read -rp "$PROMPT" ANSWER
    ANSWER=${ANSWER:-$DEFAULT}
    echo

    case "${ANSWER^^}" in
        Y)
            echo -e "${GREEN}   ✅ Running $SCRIPT...${RESET}"
            if bash "$SCRIPT_PATH"; then
                echo -e "${GREEN}   ✅ Done: $SCRIPT${RESET}\n"
            else
                echo -e "${RED}   ❌ $SCRIPT exited with an error (continuing with the rest)${RESET}\n"
                FAILED+=("$SCRIPT")
            fi
            ;;
        *)
            echo -e "${YELLOW}   ⚠ Skipped: $SCRIPT${RESET}\n"
            SKIPPED+=("$SCRIPT")
            ;;
    esac
done

echo -e "${BLUE}=========================================================${RESET}"
echo -e "${BLUE}   🏁 All tasks processed.${RESET}"
echo -e "${BLUE}=========================================================${RESET}"

if [ "${#SKIPPED[@]}" -gt 0 ]; then
    echo -e "${YELLOW}Skipped: ${SKIPPED[*]}${RESET}"
fi

if [ "${#FAILED[@]}" -gt 0 ]; then
    echo -e "${RED}Failed:  ${FAILED[*]}${RESET}"
    echo -e "${YELLOW}Re-run individual scripts directly with: bash scripts/<name>.sh${RESET}"
    exit 1
fi

echo -e "${GREEN}Done. A logout/reboot is recommended (group membership + KDE service changes).${RESET}"
