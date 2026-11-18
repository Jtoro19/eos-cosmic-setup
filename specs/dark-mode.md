# dark-mode

## Purpose

Make non-COSMIC apps dark: GTK3/GTK4/libadwaita, Qt5/Qt6, Flatpak and
Electron/Chromium apps. COSMIC's own dark mode (`is_dark`) is shipped by the
`cosmic-settings` module, which this module depends on. No font is set anywhere.

## Source of truth

`reference/modo-oscuro-cosmic.md`, adapted. Shipped data lives in
`files/dark-mode/qt5ct.conf` and `files/dark-mode/qt6ct.conf` (Appearance only,
no `[Fonts]` section so default fonts are kept).

## Files and packages touched

Per toolkit:

- GTK3/GTK4/libadwaita: package `adw-gtk-theme`; GSettings
  `org.gnome.desktop.interface` `gtk-theme='adw-gtk3-dark'` (GTK3) and
  `color-scheme='prefer-dark'` (GTK4/libadwaita, and web content that follows
  the system preference). Skipped with a warning when `gsettings` or the
  session bus is missing. No sudo.
- GTK3 apps that ignore GSettings: `~/.config/gtk-3.0/settings.ini`
  `[Settings]` gets `gtk-theme-name=adw-gtk3-dark` and
  `gtk-application-prefer-dark-theme=1` (key by key, other keys kept). GTK3
  reads this file under X11 when no XSETTINGS daemon runs, which is the case on
  COSMIC, and apps that bundle their own GTK use it too. Found with VMware
  Workstation, which ships `/usr/lib/vmware/lib/libgtk-3.so.0` and stayed light
  while every other GTK app was dark.
- Qt5/Qt6: packages `qt5ct`, `qt6ct`; `QT_QPA_PLATFORMTHEME=qt5ct` in
  `/etc/environment` (sudo). The qt6ct plugin registers both the `qt6ct` and
  `qt5ct` keys, so Qt6 apps load qt6ct and Qt5 apps load qt5ct with this one
  value. If `/etc/environment` already has a different `QT_QPA_PLATFORMTHEME=`
  line, the module warns and adds nothing. Sets only the `[Appearance]` keys
  of `~/.config/qt5ct/qt5ct.conf` and `~/.config/qt6ct/qt6ct.conf` (Fusion
  style, `darker` color scheme, `Papirus-Dark` icons), key by key with
  `ensure_ini_line ... replace`. Other sections that qt5ct/qt6ct write when
  their GUI is opened (for example `[SettingsWindow]` geometry) are left alone,
  so opening the GUI does not make the module report changes.
  Requires logout/login for the env var.
- Flatpak (only if `flatpak` exists): system remote `flathub` if missing,
  runtime `org.gtk.Gtk3theme.adw-gtk3-dark` installed system-wide, and system
  override `GTK_THEME=adw-gtk3-dark`. All with sudo, via `run_sudo`.
- Electron/Chromium: line `--force-dark-mode` in `~/.config/electron-flags.conf`,
  `brave-flags.conf` and `code-flags.conf`. This only darkens the app UI;
  `WebContentsForceDark` is deliberately not used because it recolors websites.
  Launchers: Arch's `electronNN` wrapper reads `electronNN-flags.conf`, falling
  back to `electron-flags.conf` (a per-version file, if present, wins);
  `brave-bin` (`/usr/bin/brave`) reads `brave-flags.conf`;
  `visual-studio-code-bin` (`/usr/bin/code`) reads `code-flags.conf`.
  `vesktop-flags.conf` is not touched.

## Hardware detection

None.

## Idempotency check

Every check is read-only: package presence, `gsettings get`, exact-line match
in the env and flag files, per-key match of the qt `[Appearance]` keys, `flatpak remotes`,
`flatpak info --system` and `flatpak override --system --show`. A second run
reports no changes, so `--dry-run` is accurate.

## Revert

- `gsettings reset org.gnome.desktop.interface gtk-theme` and
  `gsettings reset org.gnome.desktop.interface color-scheme`.
- Remove the two lines from `~/.config/gtk-3.0/settings.ini` (or restore its
  `.bak.<timestamp>`).
- `sudo sed -i '/^QT_QPA_PLATFORMTHEME=qt5ct$/d' /etc/environment` (or restore
  `/etc/environment.bak.<timestamp>`), then log out and back in.
- Restore `~/.config/qt5ct/qt5ct.conf` and `~/.config/qt6ct/qt6ct.conf` from
  their `*.bak.<timestamp>` files, or delete them.
- `sudo flatpak override --system --unset-env=GTK_THEME` and
  `sudo flatpak uninstall --system org.gtk.Gtk3theme.adw-gtk3-dark`.
- Remove the `--force-dark-mode` line from the three flag files.
- `sudo pacman -Rns adw-gtk-theme qt5ct qt6ct` if wanted.

## Verification

- `gsettings get org.gnome.desktop.interface color-scheme` prints
  `'prefer-dark'`; `gtk-theme` prints `'adw-gtk3-dark'`.
- After re-login, `echo $QT_QPA_PLATFORMTHEME` prints `qt5ct`; open a Qt app
  (for example `qt6ct` itself or VLC) and it is dark.
- `flatpak override --system --show` lists `GTK_THEME=adw-gtk3-dark` and
  `flatpak info --system org.gtk.Gtk3theme.adw-gtk3-dark` succeeds; a Flatpak
  GTK app is dark.
- Open Brave and VS Code: the app UI is dark.
- `./install.sh --only dark-mode --dry-run` reports "Nothing to change" after
  applying.
