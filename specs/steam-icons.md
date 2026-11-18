# steam-icons

## Purpose

Make COSMIC Workspace Icons show the real icon of Steam/Proton games. Steam
creates no desktop entry per game, so the applet has nothing to resolve the
window to. The module ships a sync script that writes one desktop entry and
one icon per installed game, and units that keep them current.

## Source of truth

Verified on the reference machine (Dead by Daylight, appid 381210):

- A running Steam/Proton game has the Wayland app_id `steam_app_<appid>`
  (confirmed with `lswt` and the X11 `WM_CLASS`).
- Steam created no per-game `.desktop` files.
- Workspace Icons resolves icons through freedesktop desktop entries by app id
  (desktop file id or `StartupWMClass`). It caches the result per app_id while
  the window exists and rescans the entries on a miss, so the game must be
  reopened after the entry is created.
- This pair made the correct icon appear after reopening the game:
  `~/.local/share/applications/steam_app_381210.desktop` and
  `~/.local/share/icons/hicolor/32x32/apps/steam_icon_381210.png` (converted
  with `magick` from Steam's cached icon).

Inputs read by the script:

- Steam root: `${XDG_DATA_HOME:-$HOME/.local/share}/Steam`, else
  `~/.steam/steam` (symlinks are resolved).
- `steamapps/appmanifest_<appid>.acf` (field `name`) in the root library and in
  every `"path"` listed in `steamapps/libraryfolders.vdf` (plus `/steamapps`).
- The icon: the first (sorted) `*.jpg` at the top level of
  `<root>/appcache/librarycache/<appid>/` (32x32).

Captured data in this repository (`files/steam-icons/`): `steam-icons-sync`,
`steam-icons-sync.service`, `steam-icons-sync.path`.

## Files and packages touched

- Package (only if missing): `imagemagick` (`magick`).
- `~/.local/bin/steam-icons-sync` (0755), and the units
  `~/.config/systemd/user/steam-icons-sync.service` and `.path` (0644).
- Generated per game: `~/.local/share/applications/steam_app_<appid>.desktop`
  and `~/.local/share/icons/hicolor/32x32/apps/steam_icon_<appid>.png`.
- Units enabled: `steam-icons-sync.path` (`WantedBy=default.target`) and
  `steam-icons-sync.service` (`WantedBy=graphical-session.target`).
  The path unit reacts to changes; the service also runs once per login, which
  covers games installed while the path unit was not running and libraries on
  other drives (those are not watched).
- If Steam is not installed, the script exits 0 quietly and the module still
  installs script and units (they are harmless), so a later Steam install is
  covered without re-running the module.

### Generated desktop entry

Exact format (key order fixed, trailing newline, no other keys):

```
[Desktop Entry]
Type=Application
Name=<name from the manifest>
Exec=steam steam://rungameid/<appid>
Icon=steam_icon_<appid>
StartupWMClass=steam_app_<appid>
Categories=Game;
Terminal=false
X-Eos-Cosmic-Setup=steam-icons
```

`Name` comes from the manifest (VDF escapes `\"` and `\\` are undone, newlines
are stripped).

### Tool filter

Steam also installs non-game apps with an appmanifest. A manifest whose name
matches `^(Proton|Steam Linux Runtime|Steamworks Common Redistributables)`
(case-sensitive) is skipped. On the reference host that leaves 3 games of 11
manifests.

### Marker ownership

The last line `X-Eos-Cosmic-Setup=steam-icons` marks a file as owned by this
module. Rules:

- A `steam_app_<appid>.desktop` with the marker is rewritten when it differs.
- A file without the marker whose content equals the generated content minus
  the marker is treated as ours (the hand-made test file of this host) and
  rewritten once with the marker.
- Any other unmarked file is left alone (a warning goes to stderr).

### Cleanup rules

`steam_app_*.desktop` files that carry the marker but whose appid is no longer
an installed game are deleted, together with `steam_icon_<appid>.png`. Files
without the marker are never deleted. The icon is refreshed only when missing
or when the cached jpg is newer than the png. If a game has no cached jpg and
no png yet, it is skipped until Steam caches it (the path unit watches
`librarycache`). If `magick` is missing, the icon is skipped with a warning
and the desktop entry is still written.

## Hardware detection

none.

## Idempotency check

Files are compared before writing; the png is written only if missing or stale.
The script prints `N added, N updated, N removed` and a second run reports 0 of
each. `--dry-run` prints `would add|update|remove ...` lines and changes
nothing. After a real change it runs `update-desktop-database` and
`gtk-update-icon-cache -f -t` when those commands exist (failures ignored).

How the module uses it: it runs the shipped repo script with `--dry-run`, turns
every `would ...` line into a `log_change` (so dry-run and real counts come from
the payload logic), and in a real run executes the installed script when there
was pending work. This runs before the units are enabled, so `enable --now`
runs the sync a second time with nothing left to do.

The path unit watches only `~/.local/share/Steam/steamapps` and
`~/.local/share/Steam/appcache/librarycache` (directory changes on add and
remove). Libraries on other drives are synced on the next login or trigger.
The service sets `StartLimitIntervalSec=0` because Steam rewrites manifests many
times during an install.

## Revert

```bash
systemctl --user disable --now steam-icons-sync.path steam-icons-sync.service
rm -f ~/.config/systemd/user/steam-icons-sync.{path,service} ~/.local/bin/steam-icons-sync
systemctl --user daemon-reload
# Delete only the marked entries and their icons:
for f in ~/.local/share/applications/steam_app_*.desktop; do
  grep -qxF 'X-Eos-Cosmic-Setup=steam-icons' "$f" || continue
  id=${f##*steam_app_}; id=${id%.desktop}
  rm -f "$f" ~/.local/share/icons/hicolor/32x32/apps/steam_icon_"$id".png
done
update-desktop-database ~/.local/share/applications
gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor
```

## Verification

- `./install.sh --only steam-icons --dry-run`, then without `--dry-run`; run it
  again: "Nothing to change".
- Open a game: `lswt` shows `steam_app_<appid>`, and Workspace Icons shows the
  game icon (reopen the game if it was already running).
- Install a new game in Steam and check that
  `~/.local/share/applications/steam_app_<appid>.desktop` appears.
- `~/.local/bin/steam-icons-sync --dry-run` reports 0 changes after a sync.
