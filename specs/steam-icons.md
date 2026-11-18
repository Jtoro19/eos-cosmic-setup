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
- A native Linux game does NOT: its app_id is its executable name. Valheim
  (892970, Unity) reports `valheim.x86_64`.
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
`steam-icons-sync.service`, `steam-icons-sync.path`, `steam-icons-learn`,
`steam-icons-learn.service`.

## Files and packages touched

- Packages (only if missing): `imagemagick` (`magick`) and `lswt` (AUR only,
  installed with `ensure_aur_packages`).
- `~/.local/bin/steam-icons-sync` and `~/.local/bin/steam-icons-learn` (0755),
  and the units `~/.config/systemd/user/steam-icons-sync.service`, `.path` and
  `steam-icons-learn.service` (0644).
- Written at runtime by the learn service (not by the module):
  `~/.config/eos-cosmic-setup/steam-wmclass.conf`.
- Generated per game: `~/.local/share/applications/steam_app_<appid>.desktop`
  and `~/.local/share/icons/hicolor/32x32/apps/steam_icon_<appid>.png`.
- Units enabled: `steam-icons-sync.path` (`WantedBy=default.target`) and
  `steam-icons-sync.service` (`WantedBy=graphical-session.target`).
  The path unit reacts to changes; the service also runs once per login, which
  covers games installed while the path unit was not running and libraries on
  other drives (those are not watched).
- `steam-icons-learn.service` (`WantedBy=graphical-session.target`, `Type=simple`,
  `Restart=on-failure`) is enabled too. If the script or unit changed in a real
  run and the service is active, the module runs `systemctl --user try-restart`.
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
StartupWMClass=<wm-class>
Categories=Game;
Terminal=false
X-Eos-Cosmic-Setup=steam-icons
```

`<wm-class>` is chosen per game:

1. An override in `~/.config/eos-cosmic-setup/steam-wmclass.conf` (lines
   `<appid>=<class>`), for games the heuristic gets wrong. Read the real value
   with `lswt` while the game runs.
2. Otherwise, if the install dir (`steamapps/common/<installdir>`) has exactly
   one top-level ELF executable (not `*.so`), the game is native and the class
   is that file name (for example `valheim.x86_64`).
3. Otherwise (Windows build run through Proton, or ambiguous), `steam_app_<appid>`.

Forcing Proton on a game with a native build makes Steam install the Windows
build, so rule 2 stops matching and rule 3 applies, which is correct.

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

## Runtime learning

Why: the window app_id of a native game is engine specific (Valheim reports
`valheim.x86_64`, Terraria is a Mono game started through a shell script with
no top-level ELF), so no disk heuristic can be general, and the default
`steam_app_<appid>` is wrong for such games. Instead of guessing, the
`steam-icons-learn` service reads the real app_id while the game runs.

How it works (loop every 3 s, using `lswt -j`; its JSON is invalid because
identifiers are unquoted, so the `"app-id": "..."` lines are matched with a
regex):

1. Only app_ids not handled earlier in the session are considered. Empty ids,
   `steam_app_*` ids and ids already covered by a desktop entry are ignored. An
   id is covered by `<id>.desktop` (case-insensitive file name) or by a
   `StartupWMClass=<id>` line (case-insensitive) in `~/.local/share/applications`,
   `/usr/share/applications`, `/usr/local/share/applications` or the flatpak
   exports dirs. The generated entries count, so a learned id is covered after
   the sync.
2. Running games are processes whose command line starts with
   `.../reaper SteamLaunch AppId=<digits>` (anchored, so shells that only mention
   the text never match). Tool appids (same name filter as the sync) are dropped.
3. Strong match: a descendant of that reaper has the app_id (case-insensitive,
   also without a `.x86_64` or `.bin.x86_64` suffix when the rest has 4+
   characters) in its command line or name.
4. Fallback: with no strong match, if exactly one Steam game is running and its
   reaper started less than 180 s ago, that game gets the mapping. Otherwise
   nothing is learned, so an unrelated app is never mapped to a game.
5. A mapping is stored as `<appid>=<app_id>` in
   `~/.config/eos-cosmic-setup/steam-wmclass.conf` (an existing line for the
   appid is replaced, never duplicated), `learned <appid> -> <app_id>` is
   printed, and `steam-icons-sync` runs so the entry gets the new
   `StartupWMClass`. The sync already rewrites a marked file whose content
   differs, so no change to the sync was needed. If the stored value already
   equals the id, nothing happens; a different stored value is replaced because
   a correct value would have covered the id in step 1.

The override file is also editable by hand (same format; the learn service
replaces a hand line only when the window app_id differs and is uncovered).
The first launch of a new native game shows the generic icon; the icon appears
after the game is reopened once (the applet caches per app_id while the window
exists). If `lswt` is missing the service logs once to stderr and idles
(60 s sleeps) instead of exiting, so systemd never restart-loops it.

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
systemctl --user disable --now steam-icons-sync.path steam-icons-sync.service steam-icons-learn.service
rm -f ~/.config/systemd/user/steam-icons-sync.{path,service} ~/.local/bin/steam-icons-sync
rm -f ~/.config/systemd/user/steam-icons-learn.service ~/.local/bin/steam-icons-learn
rm -f ~/.config/eos-cosmic-setup/steam-wmclass.conf   # learned (and hand-made) overrides
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
- Runtime learning: install a native game, open it, and check
  `journalctl --user -u steam-icons-learn` shows `learned <appid> -> <app_id>`;
  reopen the game and Workspace Icons shows its icon.
