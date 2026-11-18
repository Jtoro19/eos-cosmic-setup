# aura

## Purpose

Install Aura (the animated wallpaper manager for COSMIC) from its pinned
release and make the last wallpaper come back at every login. The old setup
used a hand-written start script that was launched from a COSMIC autostart
entry; it is replaced by one systemd user unit.

## Source of truth

- Aura v1.5.0, release tarball
  `https://github.com/antwny/aura/releases/download/v1.5.0/aura-v1.5.0-x86_64-linux.tar.gz`
  (plus its `.sha256`). It holds `aura`, a bundled `mpvpaper`, the desktop
  entry, an SVG icon, the metainfo and its own `install.sh`.
- Aura keeps the chosen wallpaper in `~/.config/aura/config.json` (keys used
  here: `current`, `output`, `autostart`). The unit reads that file, so the
  last wallpaper applied with Aura is the one restored.

How the reference machine got Aura: from this release tarball with the
upstream user install (`install.sh --user`). Evidence, comparing the
extracted tarball with the host files (sha256):

| File | Tarball | Host |
|------|---------|------|
| `aura` | `2b1c38f9...` | identical |
| `mpvpaper` | `640d0f35...` | identical |
| icon SVG | `96b6e2f8...` | identical |
| metainfo XML | `b6297f0a...` | identical |
| desktop entry | differs only by the `TryExec=`/`Exec=` lines, which the upstream installer rewrites to the absolute `~/.local/bin/aura` | same |

No package owns `aura` or `mpvpaper`; both live in `~/.local/bin`.

Captured data in this repository (`files/aura/`):

- `aura-restore`: bash script installed to `~/.local/bin/aura-restore`.
- `aura-restore.service`: systemd user unit.

The wallpapers (`~/Pictures/Wallpapers/Aura/*.mp4`) are user data and are not
part of this repository; the module never touches `~/Pictures/Wallpapers`.

## Files and packages touched

- Official packages (only if missing): `mpv`, `ffmpeg`, `jq`, `curl`.
- Install step, only when `~/.local/bin/aura` is not executable (or
  `AURA_REINSTALL=1`), mirroring the upstream user install paths:
  - `~/.local/bin/aura` and `~/.local/bin/mpvpaper` (0755)
  - `~/.local/share/applications/io.github.antwny.aura.desktop` (0644, absolute
    `TryExec`/`Exec`, same rewrite as upstream)
  - `~/.local/share/icons/hicolor/scalable/apps/io.github.antwny.aura.svg`
  - `~/.local/share/metainfo/io.github.antwny.aura.metainfo.xml`
  - `update-desktop-database` and `gtk-update-icon-cache` run only when files
    were installed, and the icon cache only if one already exists.
  The tarball is downloaded to a `mktemp` directory, never piped to a shell,
  and the upstream `install.sh` is not run. The install fails with an error
  when the `.sha256` file is unavailable or does not match (upstream only
  warns).
- `~/.local/bin/aura-restore` (0755) and
  `~/.config/systemd/user/aura-restore.service` (0644).
- Unit enabled: `aura-restore.service` (`WantedBy=graphical-session.target`).
- Legacy cleanup (backed up to `<path>.bak.<timestamp>` first, then removed):
  - `~/.config/autostart/aura.desktop`
  - `~/.local/bin/aura-autostart.sh` (an older `aura-autostart.sh.bak` is left
    alone)
  - any other `~/.config/autostart/*.desktop` whose `Exec=` line contains
    `aura`, for example `io.github.antwny.aura.desktop` that Aura could write
    if its own autostart is turned on.
- Aura autostart guard: when `~/.config/aura/config.json` exists and
  `.autostart` is not `false`, it is set to `false` with `jq` (other keys and
  jq's formatting are kept; the file is backed up first).

## How the restore works

`aura-restore` (run by the unit at login):

1. Exits 0 when an `mpvpaper` process of this user is already running (Aura or
   an earlier start owns the wallpaper; two are never started).
2. Reads `.current` from the Aura config (a missing config, a missing `jq` or
   invalid JSON is tolerated). When it is empty or not a regular file, it falls
   back to the first regular file in `~/Pictures/Wallpapers/Aura` with
   extension mp4, mkv, webm, mov, gif, png, jpg, jpeg or webp, sorted by name
   in the C locale (uppercase before lowercase). With nothing to show it logs
   to stderr and exits 0.
3. Finds `mpvpaper` (prefers `~/.local/bin/mpvpaper`, then `PATH`).
4. Waits up to 15 s for the Wayland socket (`$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY`,
   or the first `wayland-N` socket when the variable is unset in the systemd
   environment). On timeout it exits 1 so the unit retries (`RestartSec=3`).
5. Re-checks that no `mpvpaper` started meanwhile, creates
   `$XDG_RUNTIME_DIR/aura`, removes a stale `mpv_all.sock` and `exec`s
   `mpvpaper -l background -p -o "<same flags Aura uses>" "<.output or *>" "<wallpaper>"`,
   so systemd supervises mpvpaper directly.

If Aura later replaces the wallpaper by stopping the unit's `mpvpaper` with a
signal (not verified here), SIGTERM counts as a clean stop for `Restart=on-failure`, so the unit
does not fight Aura. A SIGKILL or crash makes the unit restart and bring back
the wallpaper from the config.

## Why systemd and not a .desktop autostart

COSMIC's `~/.config/autostart` did not work reliably (see
`reference/portapapeles-cosmic.md`), and the old script had to `sleep 10` and
use `systemd-run` to cope with it. A user unit tied to
`graphical-session.target` starts at the right time, is supervised, logs to the
journal and is the same mechanism the clipboard and kitty modules use. Exactly
one mechanism starts the wallpaper: the legacy entries are removed and Aura's
own autostart is kept off (otherwise both would try to run).

## Prerequisite on a new machine

`~/.config/aura/config.json` is created by Aura on its first run. Apply a
wallpaper once with Aura (`aura apply <file>` or the GUI) so `current` is set;
until then the guard does nothing and the restore uses the fallback file.

## Variables

- `AURA_VERSION` (default `v1.5.0`): release tag to download. The tarball name
  is `aura-${AURA_VERSION}-x86_64-linux.tar.gz`.
- `AURA_REINSTALL=1`: reinstall even when `~/.local/bin/aura` exists (for
  example to change version, together with `AURA_VERSION`). Changed files are
  backed up first.

## Hardware detection

None. The release is x86_64 only; the module refuses to install on another
architecture. mpvpaper needs a Wayland compositor with layer-shell (COSMIC).

## Idempotency check

The install step is skipped when `~/.local/bin/aura` is executable (no
network). Files are compared byte for byte before install, the unit is only
enabled when not enabled yet, legacy files are removed only when present and
the config is only edited when `.autostart` is not `false`. A second run
reports "Nothing to change".

On the reference machine (mpvpaper already running from the old autostart):
`ensure_user_unit_enabled` runs `systemctl --user daemon-reload` and
`systemctl --user enable --now aura-restore.service`. The unit starts, sees the
running `mpvpaper`, exits 0 and ends up inactive (dead) but enabled. The
running wallpaper is not stopped or restarted. At the next login nothing is
running, so the unit starts mpvpaper itself.

## Revert

```bash
systemctl --user disable --now aura-restore.service
rm ~/.config/systemd/user/aura-restore.service ~/.local/bin/aura-restore
systemctl --user daemon-reload
# Restore the old start mechanism from the backups (timestamps vary):
cp ~/.config/autostart/aura.desktop.bak.<timestamp> ~/.config/autostart/aura.desktop
cp ~/.local/bin/aura-autostart.sh.bak.<timestamp> ~/.local/bin/aura-autostart.sh
# Restore the Aura config if needed:
cp ~/.config/aura/config.json.bak.<timestamp> ~/.config/aura/config.json
```

Disabling the unit with `--now` stops mpvpaper when the unit owns it. To
remove Aura itself (optional): delete `~/.local/bin/aura`,
`~/.local/bin/mpvpaper`, the desktop entry, icon and metainfo listed above.
The wallpapers are never touched.

## Verification

- `./install.sh --only aura --dry-run` on a configured machine prints
  "Nothing to change".
- `systemctl --user is-enabled aura-restore.service` prints `enabled` and
  `systemctl --user status aura-restore` shows no errors (after a login it is
  active and runs mpvpaper; if Aura had already started a wallpaper it is
  inactive with exit 0).
- Apply a different wallpaper with `aura apply <file>`, log out and in: it
  comes back.
- Rename the current file, log out and in: the first file by name in
  `~/Pictures/Wallpapers/Aura` is used and the journal says so
  (`journalctl --user -u aura-restore`).
- `jq .autostart ~/.config/aura/config.json` prints `false`.
