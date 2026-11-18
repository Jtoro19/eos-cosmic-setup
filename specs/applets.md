# applets

## Purpose

Install the three third-party COSMIC panel applets used on the reference
machine (Workspace Icons, Now Playing, Lock Keys) and the configuration of
Workspace Icons. Placing them in the panel is not done here (the panel module
owns `plugins_wings` / `plugins_center`), and cosmic-panel is never restarted.

## Source of truth

| Applet | What it is | Upstream | Panel id |
|--------|-----------|----------|----------|
| Workspace Icons | Shows application icons on each workspace pill | https://github.com/crocodile/cosmic-ext-applet-workspace-icons | `io.github.crocodile.cosmic-ext-applet-workspace-icons` |
| Now Playing | Media title and controls (MPRIS) in the panel | AUR `cosmic-ext-applet-now-playing-extended-git` | `com.github.DiegoMMR.CosmicExtAppletNowPlaying` |
| Lock Keys | Caps Lock and Num Lock indicators | https://github.com/lucianosb/cosmic-applet-lock-keys | `com.lucianosb.cosmic-ext-lock-keys` |

How the reference machine had them:

- Workspace Icons: built from source and installed under `~/.local` (binary in
  `~/.local/bin`, desktop entry with an absolute `Exec=`, icon and metainfo
  under `~/.local/share`). No package owns it. Its desktop entry on the host is
  an older upstream revision (no Polish strings), so it is captured from the
  live file, not from upstream HEAD.
- Now Playing: installed with `yay` from the AUR.
- Lock Keys: built by hand and installed with sudo into `/usr` (the upstream
  `justfile` uses wrong names, see `reference/setup-lock-keys.md`). No package
  owns the files.

Captured data in this repository (`files/applets/`):

- `io.github.crocodile.cosmic-ext-applet-workspace-icons.desktop.in`: the live
  desktop entry with the home directory replaced by `@HOME@`.
- `cosmic/io.github.crocodile.cosmic-ext-applet-workspace-icons/v3/*`: the 8
  config key files, byte exact (`dim_minimized_window_icons`,
  `highlight_maximized_window_icons`, `inactive_pill_contrast_percent`,
  `max_visible_icons`, `pill_border_width`, `pill_spacing_percent`,
  `pill_style`, `show_one_icon_per_application`). The obsolete `v2` directory
  is ignored.

## Files and packages touched

Always managed (cheap, byte compared):

- `~/.local/share/applications/io.github.crocodile.cosmic-ext-applet-workspace-icons.desktop`
  (0644, rendered with `install_template`).
- `~/.config/cosmic/io.github.crocodile.cosmic-ext-applet-workspace-icons/v3/*`
  (0644, one file per key).
- AUR package `cosmic-ext-applet-now-playing-extended-git` (via `yay`).

Only during a build (applet not installed, or `APPLETS_REBUILD=1`):

- Packages (only if missing): `git`, `base-devel`, and `rust` only when
  `cargo` is not already on `PATH` (a rustup toolchain is respected). No other
  build dependencies are added: both upstream READMEs only say "the usual
  libcosmic system dependencies", which a COSMIC install already provides.
- Source checkouts in `${XDG_CACHE_HOME:-$HOME/.cache}/eos-cosmic-setup/src/`
  (`cosmic-ext-applet-workspace-icons`, `cosmic-applet-lock-keys`), shallow
  clones kept for updates.
- Workspace Icons, mirroring upstream `just install` with prefix `~/.local`:
  - `~/.local/bin/cosmic-ext-applet-workspace-icons` (0755)
  - `~/.local/share/icons/hicolor/scalable/apps/<appid>.svg` (0644)
  - `~/.local/share/metainfo/<appid>.metainfo.xml` (0644)
  - the desktop entry comes from the template above, not from upstream, so
    `Exec=` points at the user's own home. The upstream `i18n` data is compiled
    into the binary; nothing else is installed.
- Lock Keys (sudo), exactly as the reference guide:
  - `/usr/bin/cosmic-ext-lock-keys` (0755)
  - `/usr/share/applications/com.lucianosb.cosmic-ext-lock-keys.desktop` (0644)
  - `/usr/share/icons/hicolor/scalable/apps/{caps,num}-lock-symbolic.svg` (0644)
  - `gtk-update-icon-cache -f /usr/share/icons/hicolor`

No services or units are enabled.

## Hardware detection

none

## Idempotency check

- Workspace Icons counts as installed when `~/.local/bin/cosmic-ext-applet-workspace-icons`
  exists and is executable. Lock Keys counts as installed when
  `/usr/bin/cosmic-ext-lock-keys` exists. Installed applets are skipped with no
  network access and no build tooling checks.
- `APPLETS_REBUILD=1` forces `git pull --ff-only` in the checkouts (cloning if
  missing), a rebuild, and a reinstall of both manual applets. Example:
  `APPLETS_REBUILD=1 ./install.sh --only applets`.
- The desktop entry and config keys are compared byte by byte on every run.
- The AUR package is only installed when `pacman -Q` does not know it.
- In `--dry-run` a missing applet prints `[dry-run] would build <name> from <url>`
  and counts as one change; nothing is cloned or downloaded.
- A second run reports "Nothing to change".

## Sudo and network needs

- Lock Keys writes to `/usr` (sudo). Missing build packages use `pacman` via
  sudo. Now Playing is installed with `yay` (it calls sudo itself).
- Network is only used when something is missing or `APPLETS_REBUILD=1`:
  `git clone` / `git pull` and cargo crate downloads. Compiling libcosmic
  based applets takes several minutes.

## Revert

1. Remove the applets from the panel first (COSMIC Settings, Desktop, Panel,
   Applets), so the panel does not keep a dangling entry.
2. Workspace Icons:
   `rm -f ~/.local/bin/cosmic-ext-applet-workspace-icons
   ~/.local/share/applications/io.github.crocodile.cosmic-ext-applet-workspace-icons.desktop
   ~/.local/share/metainfo/io.github.crocodile.cosmic-ext-applet-workspace-icons.metainfo.xml
   ~/.local/share/icons/hicolor/scalable/apps/io.github.crocodile.cosmic-ext-applet-workspace-icons.svg`
   and `rm -r ~/.config/cosmic/io.github.crocodile.cosmic-ext-applet-workspace-icons`
   (or restore the `*.bak.<timestamp>` files).
3. Now Playing: `yay -Rns cosmic-ext-applet-now-playing-extended-git`.
4. Lock Keys:
   `sudo rm /usr/bin/cosmic-ext-lock-keys
   /usr/share/applications/com.lucianosb.cosmic-ext-lock-keys.desktop
   /usr/share/icons/hicolor/scalable/apps/caps-lock-symbolic.svg
   /usr/share/icons/hicolor/scalable/apps/num-lock-symbolic.svg`
   then `sudo gtk-update-icon-cache -f /usr/share/icons/hicolor`.
5. `rm -r ~/.cache/eos-cosmic-setup/src` to drop the source checkouts.

## Verification

- `./install.sh --only applets --dry-run` reports "Nothing to change" on a
  machine where all three applets are installed.
- `test -x ~/.local/bin/cosmic-ext-applet-workspace-icons` and
  `test -e /usr/bin/cosmic-ext-lock-keys` succeed; `pacman -Q
  cosmic-ext-applet-now-playing-extended-git` prints a version.
- `cmp` of the config key files against `files/applets/cosmic/...` shows no
  difference.
- The three applets appear in COSMIC Settings, Desktop, Panel, Applets (log out
  and in if a freshly built one is missing).
- `shellcheck -x install.sh lib/common.sh modules/*.sh files/kitty/kitty-cosmic-colors.sh`
