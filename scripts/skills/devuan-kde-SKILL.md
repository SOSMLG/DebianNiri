# System context: Devuan/Debian + KDE Plasma

This machine was set up with `devuan-kde-setup`, a post-install polish
toolkit. Keep the following in mind when suggesting commands or diagnosing
issues on this system:

## Package management
- **APT-based** (Debian/Devuan), not Arch/Fedora/Nix. Use `apt`/`apt-get`,
  never `pacman`, `dnf`, or `nix-env`.
- `apt-get install -y <pkg>` for installs, `apt-get purge -y <pkg>` to
  remove, `apt-get autoremove --purge -y` to clean up orphaned deps.
- Flatpak is available (via Discover or `flatpak install flathub <app>`)
  as a secondary source if a package isn't in Debian's repos.

## Init system
- **Devuan** ships without systemd by default (sysvinit or OpenRC,
  user's choice at install time) — **do not assume `systemctl` works.**
  Check for it first: `command -v systemctl && [ -d /run/systemd/system ]`.
  If that's false, use `service <name> start|stop|restart` and
  `update-rc.d <name> defaults` instead of `systemctl enable`.
- If this is plain **Debian** rather than Devuan, systemd is the default
  and `systemctl` is safe to assume.
- Check `/etc/devuan_version` (Devuan) vs `/etc/debian_version` (Debian)
  to tell which one you're on.

## Desktop environment
- **KDE Plasma** (Plasma 6 unless noted otherwise) — not GNOME, Cinnamon,
  or XFCE. Desktop-specific commands should target KDE's own tools:
  - Config files: `~/.config/kwinrc` (window manager/compositor),
    `~/.config/kdeglobals` (app style/colors/fonts),
    `~/.config/kglobalshortcutsrc` (global keyboard shortcuts),
    `~/.config/plasma-org.kde.plasma.desktop-appletsrc` (panel layout —
    fragile to hand-edit; prefer Plasma's own scripting D-Bus API,
    `qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript`).
  - Writing config: `kwriteconfig6` (Plasma 6) or `kwriteconfig5` (Plasma 5)
    — check which is present, don't assume.
  - Applying live: `plasma-apply-colorscheme`, `plasma-apply-desktoptheme`,
    `plasma-apply-lookandfeel`, `plasma-apply-cursortheme`.
  - File manager is **Dolphin** (KIO-based — trash/network shares/thumbnails
    work through KIO, not gvfs). Terminal is whatever's set as the default
    (check `~/.config/xfce4/helpers.rc`-equivalent — KDE uses
    `kde-open`/`x-terminal-emulator` via `update-alternatives`).
  - Global shortcuts are **not** gsettings/dconf (that's GNOME/Cinnamon) —
    they're `kglobalaccel`, backed by `kglobalshortcutsrc` plus a matching
    `.desktop` file with `X-KDE-GlobalAccel-CommandShortcut=true`.

## This toolkit's own conventions (for consistency if extending it)
- Scripts live in `scripts/`, each independently runnable, each with its
  own inline `ask()`/`log_*`/`install_pkgs` helpers (a couple of
  newer scripts source `scripts/lib/common.sh` instead — both patterns
  exist, don't need unifying).
- Every apt action checks what's actually installed first — nothing is
  blindly force-purged, so scripts are safe to re-run.
- Config values that can't be verified against a real documented key are
  never guessed at silently — they're printed as a manual checklist
  instead. If you're not sure a KWin/kdeglobals key is real, say so
  rather than writing it speculatively.
