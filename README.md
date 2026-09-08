# devuan-kde-setup

Post-install polish for a Devuan (or Debian) box where **KDE Plasma is
already installed** by the distro's own installer. This does *not* install
KDE — it debloats the default Plasma task install toward a minimal-but-
functional desktop, then fills in the "why doesn't this just work like
Mint" gaps: codecs, WiFi/Bluetooth firmware, a unified software center,
printing, a firewall panel, Timeshift for system snapshots, and (new) a
theming pass — Darkly, KWin Blur/Magic Lamp, a centered KRunner, a glass
Konsole profile — while staying an opt-in, à-la-carte toolkit rather than
a heavyweight installer.

Structure follows the same "ordered runner + flat scripts/ dir" pattern as
the DebianSway repo this was modeled after.

## Fixes + additions in this pass

**Two real bugs fixed, not just new features:**

- **`aiOpencode.sh` and `devToolsExtras.sh` were both completely broken.**
  Both `source "$SCRIPT_DIR/../lib/common.sh"` — a file that never
  actually existed in this repo, so both exited immediately on that line
  before doing anything. `scripts/lib/common.sh` now exists.
- **`aiOpencode.sh`'s Super+A hotkey didn't work on KDE at all.** It used
  `gsettings`/`org.cinnamon.desktop.keybindings` — that's Cinnamon's
  config system (GNOME/dconf-based), not KDE's. Plasma doesn't read
  dconf for its own shortcuts, so the binding silently did nothing. A few
  other leftover "Cinnamon"/"OpenRC" references (and a missing skill file
  it pointed at) suggest this script was adapted from a sibling
  Cinnamon-based toolkit and not fully re-targeted. It's now wired
  through kglobalaccel — the real mechanism, verified against two
  independent write-ups of what System Settings' own "Add Command..."
  button does under the hood (a `.desktop` launcher with
  `X-KDE-GlobalAccel-CommandShortcut=true`, referenced from
  `~/.config/kglobalshortcutsrc`). `scripts/skills/devuan-kde-SKILL.md`
  (also previously missing) now exists too, describing this system
  accurately instead of as a Cinnamon box.
- A stray duplicate `AddUserToGroups.sh` (an earlier, worse draft —
  no shebang, no root check, no idempotency check) sat alongside the
  real `addUserToGroups.sh` and has been removed.

**New: a Catppuccin visual identity end-to-end, matching this toolkit's
XFCE sibling project — Mocha flavour, Red accent (a black chassis, red
TrackPoint nub, if you're on a ThinkPad):**

- **`catppuccinPlasma.sh`** — the official
  [catppuccin/kde](https://github.com/catppuccin/kde) Global Theme
  (prebuilt/pre-rendered by their own CI, unlike Darkly there's no
  compile step), [ljmill/catppuccin-icons](https://github.com/ljmill/catppuccin-icons)
  (the same `Catppuccin-SE` set as the XFCE sibling, with the same
  memory-optimized `Catppuccin-SE-Local` build — see that project's
  notes on why), and a self-authored "Catppuccin Red" Konsole profile
  using the official Catppuccin terminal ANSI mapping. **This sets the
  same things `fancyPlasma.sh` sets** (style/colors/window decoration) —
  they're alternatives, not additive, so `fancyPlasma.sh`'s default
  flipped from `Y` to `N` here; whichever you run *last* is what's active.
- **`bootThemeSetup.sh`** — carries the theme to Plymouth (boot splash)
  and GRUB (same as the XFCE sibling, both DE-agnostic), plus the SDDM
  login screen via [catppuccin/sddm](https://github.com/catppuccin/sddm)
  (XFCE's equivalent used LightDM; this uses SDDM, KDE's actual display
  manager). Same invasiveness disclaimer as the XFCE version: it's the
  only script here touching `/etc/default/grub` and the initramfs, every
  edit is backed up, and it checks for GRUB/SDDM before touching either.
- **`bluetoothSetup.sh`** — bluez, Bluedevil (KDE's native applet — no
  Blueman, that would just be two tray icons fighting over one adapter),
  and the part that actually trips people up: Bluetooth *audio*
  specifically, detecting PipeWire vs PulseAudio rather than installing
  both blind, so A2DP stereo (not just pairing) works for headsets/earbuds.

**Enhanced, not new:**

- **`usefulApps.sh`'s TLP option** now removes `power-profiles-daemon`
  first (the two fight over the same power knobs if both run) and offers
  an 80%-charge-cap on hardware that actually exposes the sysfs threshold
  — same logic as the XFCE sibling's `hardwareSupport.sh`.
- **`desktopEssentials.sh`** gained a `packagekit` install — without it,
  Discover has no way to see (or notify about) apt updates at all, so
  the panel's update notification silently never fires. Also: enabling
  the firewall is now a real option (SSH-safe deny-incoming, same guard
  logic as the XFCE sibling) instead of a permanent "install only, turn
  it on yourself" — still opt-in, still off by default, just no longer a
  dead end if you do want it on.

## Structure

```
devuan-kde-setup/
├── run.sh                        # main entry point — run this
├── scripts/
│   ├── addUserToGroups.sh        # input/video/render groups
│   ├── kdeDebloat.sh             # remove games/edu/PIM bloat, Kate/Konqueror/Dragon Player, disable Baloo
│   ├── catppuccinPlasma.sh       # Catppuccin (Mocha, Red) Global Theme, icons, Konsole profile
│   ├── bootThemeSetup.sh         # Plymouth splash + GRUB theme + SDDM login screen (boot → login)
│   ├── touchpadTrackpointFix.sh  # usbhid mousepoll fix + optional libinput tuning
│   ├── hardwareSupport.sh        # WiFi/BT firmware, CPU microcode, fwupd firmware updates
│   ├── bluetoothSetup.sh         # bluez, Bluedevil, and Bluetooth audio (PipeWire/PulseAudio) bridging
│   ├── multimediaCodecs.sh       # ffmpeg/GStreamer codecs + DVD playback
│   ├── firefoxHarden.sh          # installs + hardens firefox-esr (Betterfox)
│   ├── policies.json             # firefox enterprise policy used by the above
│   ├── installFonts.sh           # Noto, Font Awesome, JetBrainsMono Nerd Font
│   ├── terminalButterbash.sh     # installs bundled ButterBash
│   ├── fastfetchConfig.sh        # fastfetch + curated config presets
│   ├── usefulApps.sh             # VLC, TLP (+ ThinkPad battery thresholds), small completeness packages
│   ├── desktopEssentials.sh      # Flatpak/Discover, PackageKit, printing, Partition Manager, firewall panel
│   ├── fancyPlasma.sh            # ★ (alternative look) Darkly, Blur + Magic Lamp, centered KRunner, glass Konsole
│   ├── timeshiftSetup.sh         # Timeshift system snapshot/restore tool
│   ├── installPhotogimp.sh       # (optional) GIMP + PhotoGIMP layout/theme, fetched live from GitHub
│   ├── installVscodium.sh        # (optional) VSCodium via official APT repo
│   ├── vscodiumDevSetup.sh       # (optional) VSCodium C++/Python dev environment
│   ├── aiOpencode.sh             # OpenCode AI agent + Super+A hotkey + system skill file
│   ├── devToolsExtras.sh         # (optional) btop, eza, bat, zoxide, Neovim+lazy.nvim, KeePassXC
│   ├── gamingSetup.sh            # (optional) Heroic Games Launcher / Steam / Wine
│   ├── vesktopTelegram.sh        # (optional) Vesktop (Discord client) / Telegram
│   ├── lib/common.sh             # shared helpers sourced by aiOpencode.sh / devToolsExtras.sh only
│   └── skills/devuan-kde-SKILL.md # system context file for AI coding agents (OpenCode/Claude Code)
├── butterbash/                   # bundled copy of butterbash-main, used offline
└── README.md
```

Scripts marked ★ are new additions built from a YouTube walkthrough
rather than part of the toolkit's original scope — see that script's
own writeup below for exactly what's automated vs. what's a printed
manual step.

## Usage

```bash
cd devuan-kde-setup
chmod +x run.sh scripts/*.sh
./run.sh
```

Run it as your **normal user**, not as root and not with `sudo bash run.sh`.
Every script calls `sudo` itself for the specific commands that need it —
this matters because Firefox's profile, your `~/.bashrc`, and KDE's config
files all need to land in *your* `$HOME`, not root's.

`run.sh` walks through each script in order and asks `Y/n` (or `y/N`) before
running it, exactly like DebianSway's `run.sh`. You can also run any script
standalone, e.g. just the touchpad fix:

```bash
bash scripts/touchpadTrackpointFix.sh
```

## What each step does

**addUserToGroups.sh** — adds you to `input`, `video`, `render` groups.
Needed for some touchpad/trackpoint diagnostics and GPU acceleration.

**kdeDebloat.sh** — purges (only what's actually installed, never guesses):
- KDE games (`kdegames` suite: kmahjongg, kpat, kmines, ksudoku, ...)
- KDE education suite (kalzium, kstars, parley, marble, ...)
- The PIM/Akonadi stack (Kontact, KMail, KOrganizer, Akregator, Akonadi
  background services) — this is the single biggest idle-RAM group on a
  default KDE install
- Elisa, Kamoso, Minuet, JuK, plasma-welcome, khelpcenter (replaced by VLC
  and your own workflow)
- Kate, Konqueror, Dragon Player (replaced by VSCodium, Dolphin, and VLC)

Then runs `apt autoremove --purge` + `apt clean`, disables Baloo file
indexing for your user, and optionally shaves KDE's animation duration
down for a snappier feel. Plasma itself, Dolphin, Konsole, Kate, Okular,
Gwenview, Ark, System Settings, SDDM, etc. are never touched.

Every category is its own y/N prompt, so you can keep the games or the
PIM suite if you actually use them.

**catppuccinPlasma.sh** — an alternative to fancyPlasma.sh below. Installs
the official [catppuccin/kde](https://github.com/catppuccin/kde) Global
Theme (Mocha flavour, Red accent, Classic window decoration — no compile
step, unlike Darkly, since Catppuccin ships pre-rendered), the same
`Catppuccin-SE`/`Catppuccin-SE-Local` icon pipeline as this toolkit's XFCE
sibling project, and a self-authored "Catppuccin Red" Konsole profile.
**This sets the same things fancyPlasma.sh does** — run whichever one you
want *last*; that's the one that stays active. Re-run it after installing
new apps to refresh the icon set.

**bootThemeSetup.sh** — the part before you reach Plasma at all: a
Catppuccin Plymouth boot splash, a Catppuccin GRUB menu theme, and the
Catppuccin SDDM login screen. The most invasive script in the toolkit —
it's the only one touching `/etc/default/grub` and rebuilding the
initramfs — so every file it edits is backed up first, and it checks
GRUB/SDDM are actually present before touching either rather than
assuming a particular boot setup.

**touchpadTrackpointFix.sh** — applies the fix from your `touchpadfix` note:

```
/etc/modprobe.d/mousepoll.conf:
options usbhid mousepoll=2
```

backing up any existing file first, rebuilding initramfs, and attempting a
live `modprobe -r usbhid && modprobe usbhid` so you don't have to reboot
immediately (falls back gracefully to "reboot to apply" if the module is
busy). Optionally also drops a libinput Xorg conf snippet (tap-to-click,
natural-scroll off, trackpoint acceleration) — skip this if you're on
Wayland and just use KDE's own Touchpad settings panel instead.

**hardwareSupport.sh** — the "why doesn't my WiFi/Bluetooth work" fix,
which is almost always a missing non-free firmware blob rather than an
actual driver bug:
- Common WiFi/Bluetooth firmware for Intel, Realtek, Atheros, and
  Broadcom chips (`firmware-iwlwifi`, `firmware-realtek`,
  `firmware-atheros`, `firmware-brcm80211`, plus the broader
  `firmware-misc-nonfree`/`firmware-linux`). These are inert on hardware
  they don't match — small blob files sitting unused in `/lib/firmware` —
  so installing the common set doesn't conflict with staying minimal.
- CPU microcode, auto-detected from `/proc/cpuinfo` (`intel-microcode` or
  `amd64-microcode`, never both, never guessed if detection is
  inconclusive).
- `fwupd` for BIOS/UEFI and peripheral firmware updates via LVFS, plus
  `plasma-discover-backend-fwupd` so updates show up right in Discover —
  the closest KDE-native equivalent to Mint's Driver Manager.

**bluetoothSetup.sh** — the layer on top of the firmware blob above: the
actual bluez stack, Bluedevil (KDE's own applet — no Blueman, that's the
GTK-desktop equivalent and would just add a second tray icon fighting for
the same adapter), and Bluetooth *audio* specifically. Detects PipeWire
vs PulseAudio rather than installing both blind, since that's the part
that actually trips people up: pairing succeeds, but A2DP stereo silently
doesn't work because the audio server has no Bluetooth module loaded.

**multimediaCodecs.sh** — the single most common "why doesn't this just
work like Mint" complaint: MP3s, H.264/H.265 video, and DVDs don't play
out of the box on a stock Debian/Devuan install because the codecs are
licensing-encumbered and live outside `main`. Installs `ffmpeg` and the
full GStreamer plugin set, plus `libdvd-pkg` for DVD playback. That last
one is the one genuine gotcha in this whole toolkit: it builds
`libdvdcss` from source via a debconf-driven step that can hang waiting
for input if mishandled. This runs it under
`DEBIAN_FRONTEND=noninteractive` wrapped in a hard 5-minute `timeout`, so
the script can never block indefinitely, and then verifies the build
actually succeeded by checking for the resulting `libdvdcss2` package
rather than assuming.

**firefoxHarden.sh** — installs `firefox-esr` if it's missing, pulls the
pinned [Betterfox](https://github.com/yokoffing/Betterfox) `user.js`
(privacy/performance prefs), layers a few extra hardening prefs on top,
installs `policies.json` (disables telemetry/Pocket/sponsored content,
force-installs uBlock Origin, adds privacy-respecting search engine
shortcuts), replaces the `.desktop` launcher, and installs a `~/.local/bin`
wrapper so the hardened profile re-applies on every launch — same
mechanism as the `harden_firefox.sh` you gave me, just made Devuan-aware
and defaulted to ESR.

**installFonts.sh** — Noto (Latin + Arabic + Emoji), Font Awesome, and
JetBrainsMono Nerd Font (always the *latest* GitHub release, not pinned,
with a hardcoded fallback URL if the GitHub API is rate-limited). Also
writes a `fontconfig` preference file setting sane monospace/sans/serif
defaults and enabling subpixel hinting.

**terminalButterbash.sh** — installs the bundled `butterbash/` directory
(no network dependency on the original repo). Gives you a saner prompt,
fzf integration, and quality-of-life aliases/functions in bash.

**fastfetchConfig.sh** — installs `fastfetch` (system info on terminal
open) and pulls a set of curated config presets (`config`/`minimal`/
`fancy`/`neon`/`debian-red`/`justaguy`/`server`) from the same
`butterscripts` repo used elsewhere in this toolkit's ecosystem. `neon`
is set as the default — swap any time with
`cp ~/.config/fastfetch/<preset>.jsonc ~/.config/fastfetch/config.jsonc`.

**usefulApps.sh** — VLC, archive format support for Ark (7z/rar), Dolphin
thumbnailers for media/RAW photos, and optionally qBittorrent and TLP
(laptop power management) if you want them. TLP now also removes
`power-profiles-daemon` first if present (the two fight over the same
power knobs — CPU governor, PCIe ASPM — if both run), and on hardware
that actually exposes a charge-threshold sysfs entry (ThinkPads via
`thinkpad_acpi`, and some others), offers to cap charging at 80% for
long-term battery health. Also closes a small gap this toolkit itself
would otherwise leave open: if `kdeDebloat.sh` removed Dragon Player/
Elisa earlier, video/audio MIME defaults would otherwise keep pointing
at a now-uninstalled app. Installing VLC here also points common video/
audio types at it via `xdg-mime`, so double-clicking a video doesn't hit
a dead reference.

**desktopEssentials.sh** — the "closest to Mint" completeness pass, each
part its own y/N prompt:
- **Flatpak + Flathub**, plus `plasma-discover-backend-flatpak` — turns
  Discover into a unified software center covering both `apt` and
  Flatpak, similar to Mint's Software Manager.
- **PackageKit** — without this, Discover has literally no way to see or
  notify about pending `apt` updates, so the panel's update notification
  (the closest thing Devuan/Debian has to Mint's Update Manager icon)
  silently never fires no matter how long you wait.
- **Printing** — CUPS, `cups-browsed` for automatic network/IPP printer
  discovery, and `printer-driver-all` (Debian's broad driver metapackage,
  covering most brands without needing to guess which one you have).
  Starts the CUPS service and adds you to the `lpadmin` group so you can
  manage printers from System Settings without a password prompt every
  time.
- **KDE Partition Manager** (`partitionmanager`).
- **Firewall control panel** (`plasma-firewall` + `ufw`) — installed by
  default; *enabling* it is a separate, still-opt-in-and-off-by-default
  prompt, with an SSH-safe guard (checks for an active SSH session or a
  listening sshd and allows port 22 through *before* flipping to
  default-deny, so this can't lock you out of your own box over SSH).

**fancyPlasma.sh** ★ *(alternative look — defaults to N since
catppuccinPlasma.sh above sets the same things and is now the default)* —
the theming pass pulled from a "make KDE look modern" YouTube walkthrough
(Darkly + Ant Dark, blur, rounded corners, a floating titlebar, centered
KRunner, a cleaner panel, a glass Konsole). Split honestly between what's
genuinely scriptable and what isn't, same bar as everything else in this
toolkit — a wrong KWin/kdeglobals config key doesn't error, it just
silently writes an unused key and nothing visibly changes, so nothing
here was guessed without a source:

- **Darkly** (application style + color scheme + window decoration) —
  built from [Bali10050/Darkly](https://github.com/Bali10050/Darkly)
  source using that project's own documented Kubuntu/apt package list
  (KF6-only subset — Plasma 6's decoration API is KF6-only regardless,
  so nothing is lost skipping the KF5 half of their list), with the
  git branch chosen based on your actual installed Plasma version
  (`Darkly-6.4` below Plasma 6.5, `main` otherwise — the project's own
  compatibility notes). Style and color scheme apply via `kwriteconfig`
  and `plasma-apply-colorscheme`, both well-documented; the window
  decoration line is a best-effort guess at Darkly's plugin ID with a
  one-line manual fallback if it doesn't visibly stick.
- **KWin Blur** and **Magic Lamp** — both real built-in KWin effects,
  toggled via `kwinrc`'s documented `Plugins` group (the stock
  scale-based minimize effect is disabled alongside Magic Lamp so they
  don't conflict over which one plays).
- **KRunner centered** — `krunnerrc`'s `FreeFloating` key, the same fix
  documented on the Arch Wiki.
- **A "Devuan Glass" Konsole profile** — self-written, not downloaded:
  bigger monospace font, the built-in White on Black color scheme,
  ~30% background transparency with blur, set as your default profile.
- **Panel cleanup** — removes the Pager and Show Desktop widgets
  through Plasma's own **scripting D-Bus API**
  (`org.kde.PlasmaShell.evaluateScript`), not hand-edited appletsrc —
  this toolkit treats that config file the same way `kwriteconfig-edit`-
  style tooling does: never touch it with `sed`/manual parsing. Safe to
  skip since `Ctrl+Super+Arrows` and `Super+D` already do the same job.

What it deliberately leaves as a printed manual checklist instead of
guessing at: **Ant Dark** (the panel/widget style from the video) is
KDE-Store-distributed, which needs the KNewStuff/OCS protocol rather
than a plain download URL, so there's no way to verify a fetch for it
the way there is for Darkly's GitHub repo — use System Settings' own
"Get New" dialog. Darkly's **own** transparency sliders, corner radius,
and floating-titlebar toggle live inside Darkly's settings panel, not a
documented KWin key. **Accent color from wallpaper** is a real Plasma
feature but is D-Bus-driven rather than a static config value. The
**Window List** widget, centering panel icons with spacers, and a
custom menu icon all need either an exact applet ID or a file path only
you have — all quick by hand, all listed at the end of the script's
own output.

**timeshiftSetup.sh** — installs Timeshift, Mint's signature "snapshot
before a risky change, roll back in a couple clicks if it breaks"
safety net. On Debian/Devuan the package depends on plain `cron`, not
systemd, so it works fine on Devuan's default init setup — this was
checked specifically rather than assumed, since some distros' packaging
of similar tools does lean on systemd timers. This script makes sure a
cron daemon is present and installs the tool, but deliberately does
**not** auto-configure a snapshot device or schedule: that's a one-time
choice with real disk-space implications, and Timeshift's own setup
wizard (`sudo timeshift-launcher`, or find it in the app menu) is quick
and worth doing deliberately rather than guessed on your behalf.

**installPhotogimp.sh** *(optional, defaults to skip)* — installs GIMP via
apt and applies [PhotoGIMP](https://github.com/Diolinux/PhotoGIMP)'s
Photoshop-like menu layout, keyboard shortcuts, and single-window theme.
Files are fetched live from GitHub at install time rather than bundled:
it looks up the latest release tag via the GitHub API, and if that's
unavailable (rate-limited, etc.) it falls back to a pinned known-good tag
(currently `3.1`) so the script still works. Either way it downloads that
tag's source tarball via `codeload.github.com`, verifies the expected
`.config/GIMP/3.0/` layout is actually present before touching anything,
and only then proceeds.

Two deliberate adaptations from the upstream files:
- The upstream `.desktop` file assumes GIMP was installed via **Flatpak**
  (`Exec=flatpak run ... org.gimp.GIMP`). This installs GIMP natively via
  `apt` instead (consistent with the rest of this toolkit), so the `Exec`
  line is rewritten to launch the real `/usr/bin/gimp` — everything else
  in the `.desktop` file (name, icon, MIME types) is left untouched.
- PhotoGIMP's config targets GIMP **3.0**'s config format
  (`~/.config/GIMP/3.0/`), which is what Devuan Excalibur/Debian trixie's
  `apt` package installs. GIMP 2.10 uses an incompatible config layout, so
  the script checks the actually-installed GIMP version first and refuses
  to apply the config if it doesn't match, rather than silently copying
  files GIMP won't understand.

Any existing GIMP config is backed up (timestamped) before PhotoGIMP's
files are laid down, and it's an overlay, not a wipe — anything you
already had that PhotoGIMP doesn't ship (custom brushes, scripts, etc.)
is left in place.

**installVscodium.sh** *(optional, defaults to skip)* — installs
[VSCodium](https://vscodium.com) (telemetry-free VS Code build) through its
official APT repository, so it keeps updating via normal `apt upgrade`
instead of going stale like a one-off downloaded `.deb` would.

**gamingSetup.sh** *(optional, defaults to skip — asks per-component)*:
- **Core gaming libraries** — Vulkan (64+32-bit), Mesa utils, GameMode,
  MangoHud.
- **Steam** — installed via **Valve's own `steam_latest.deb`**
  (`repo.steampowered.com`), not Debian's contrib package. This was a
  deliberate choice: it needs zero edits to `/etc/apt/sources.list` (no
  contrib/non-free wrangling), and the `.deb` sets up Valve's own signed
  APT repo for itself so it keeps updating normally afterward.
- **Heroic Games Launcher** — always grabs the *latest* release `.deb`
  straight from the GitHub API (not pinned to v2.22.0), so it won't go
  stale as new versions ship.
- **Wine** — enables i386 multiarch and installs `wine` + `winetricks` so
  you can run Windows `.exe` apps directly. Run `winecfg` once afterward to
  set up your first Wine prefix.

**vscodiumDevSetup.sh** *(optional, defaults to skip — asks per-section)* —
configures VSCodium for C++ and Python coursework. Installs itself first via
`installVscodium.sh` if it isn't already present. Worth knowing before you
run it:

Two extensions people expect from real VS Code **do not work on VSCodium**,
so this uses what the VSCodium community actually settled on instead:

- **C/C++**: Microsoft's `ms-vscode.cpptools` added a license-enforced
  runtime check in April 2025 that refuses to run on VSCodium/Cursor/other
  forks — it's not "unavailable," it's actively blocked. This installs
  **clangd** (language server) + **CodeLLDB** (debugger) instead, which is
  open-source, on Open VSX, and works well for GCC/Clang projects on Linux.
  Packages: `build-essential gdb clangd clang-format cmake`.
- **Python**: **Pylance** is closed-source and Microsoft has confirmed on
  the record it will never publish it to Open VSX. This installs
  **basedpyright** instead — an actively maintained open-source Pyright
  fork that specifically reimplements most of Pylance's IntelliSense
  features for VSCodium users, alongside `ms-python.python` (still fine —
  it's open-source) and **Ruff** for fast linting/formatting.
  Packages: `python3 python3-pip python3-venv`.

Then it:
- Writes sane defaults into VSCodium's `settings.json` — but **merges**
  them in via a small Python script rather than overwriting the file: your
  existing settings are always backed up first, and any key you've already
  set yourself is left alone. Sets `python.languageServer: None` because
  basedpyright's own docs require it (otherwise you get duplicate
  diagnostics from `ms-python.python`'s built-in Jedi server).
- Creates a starter project at `~/Projects/vscodium-starter` with a
  `main.cpp` and `main.py` plus a working `tasks.json`/`launch.json`, so
  `Ctrl+Shift+B` builds and `F5` debugs immediately in both languages —
  nothing to hand-configure first. Skipped automatically if that folder
  already exists, so it won't touch your own projects.

One thing left out on purpose: some gaming-setup scripts also force
Wayland-specific env vars (`SDL_VIDEODRIVER=wayland`, a hardcoded
`WAYLAND_DISPLAY=wayland-0`, etc.) globally via `~/.profile`. Those were
written for a bare Sway session and can fight with KDE Plasma's own
per-app scaling under a Plasma Wayland session, so this toolkit doesn't
apply them. If Steam or Heroic look blurry/mis-scaled under Plasma
Wayland, that's worth a dedicated look rather than a blanket env-var
hack — ask and I'll put together something KDE-specific.

**aiOpencode.sh** — installs the [OpenCode](https://opencode.ai) AI
coding agent, binds Super+A to launch it in a terminal, and drops a
system "skill" file so AI tools (this one, Claude Code, etc.) know
they're on a Devuan/KDE box rather than guessing. The hotkey goes
through kglobalaccel — a `.desktop` launcher with
`X-KDE-GlobalAccel-CommandShortcut=true`, referenced from
`~/.config/kglobalshortcutsrc` — the same mechanism System Settings'
own Shortcuts > "Add Command..." uses internally. Like this toolkit's
other KDE config writes, it takes effect at your next login, not live.

**devToolsExtras.sh** *(optional, defaults to skip)* — a curated grab
bag: btop, eza, bat, a zoxide presence check, Neovim + lazy.nvim with a
minimal starter config, and KeePassXC.

**vesktopTelegram.sh** *(optional, defaults to skip — asks per-app)*:


- **Vesktop** — Vencord's standalone Discord client (better Linux/Wayland
  support, screen-share, built-in Vencord mods), installed from its
  *latest* GitHub release `.deb` via the GitHub API — not pinned to
  v1.6.5, so it keeps working as new versions ship.
- **Telegram Desktop** — same method as your `DiscordAndTelegram.sh`:
  official `tar.xz` from `telegram.org/dl/desktop/linux`, extracted to
  `~/.local/opt/Telegram`, symlinked into `~/.local/bin/telegram`, with a
  `.desktop` entry. No sudo needed for this half at all — it's entirely
  user-space.

## Notes / things worth knowing before you run it

- Every apt action first checks what's *actually installed* — nothing is
  blindly force-purged, so re-running is safe and idempotent.
- `kdeDebloat.sh` never removes Plasma itself, only bundled apps. If you
  rely on Kontact/KMail for email, or KDE's education apps, just answer
  `n` to that specific category.
- Devuan doesn't run systemd, so anything that would normally be
  `systemctl enable --now foo` falls back to `service foo start` where
  relevant (TLP, CUPS, fwupd) — but most of what's here (Baloo, apt,
  config files, modprobe, cron) is init-system agnostic. Timeshift in
  particular was specifically checked to depend on plain `cron` rather
  than systemd before it went in this toolkit.
- `fancyPlasma.sh` builds Darkly from source — expect the dependency
  install + compile step to take a few minutes on modest hardware. If
  the build itself fails, everything else in the script still runs;
  nothing else here depends on Darkly succeeding.
- Nothing in this toolkit auto-enables a firewall deny rule — you turn
  that on yourself once you've confirmed it's safe. Same philosophy as
  everything else here: install and get out of the way, don't silently
  change your machine's behavior in ways you didn't ask for.
- Reboot (or at least log out/in) after a full run — group membership,
  the mousepoll fix, newly installed firmware/microcode, and Baloo all
  benefit from a fresh session.

## Video credit

`fancyPlasma.sh` was built from watching a "make KDE Plasma look
modern" YouTube walkthrough covering Darkly, Ant Dark, KWin Blur,
rounded corners, a floating titlebar, centered KRunner, panel cleanup,
and a transparent/blurred Konsole. Not everything demonstrated made it
into the script — Ant Dark specifically is KDE-Store-distributed with
no plain download URL to verify against, and a few KWin/Darkly settings
don't have a documented config key to set safely from a script — those
are called out explicitly in the script's own comments and printed as
a short manual checklist at the end of its output instead of being
guessed at.
