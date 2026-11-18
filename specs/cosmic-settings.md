# cosmic-settings

## Purpose

Apply the COSMIC desktop settings of the reference machine (tiling, keyboard,
theme, icons, shortcuts, idle, screenshots, Files, Terminal) by installing
individual cosmic-config key files, without touching any key that is not
shipped.

## Source of truth

cosmic-config stores one file per key: `~/.config/cosmic/<component>/v<N>/<key>`,
each holding one RON value. The payload is a byte-exact copy of those files in
`files/cosmic/<component>/v<N>/<key>`, except for the two noted below.

| Component (version) | Keys shipped and value |
|---------------------|------------------------|
| `com.system76.CosmicComp` (v1) | `autotile` true; `autotile_behavior` PerWorkspace; `active_hint` true; `appearance_settings` (clip floating and tiled windows, shadow on tiled); `input_default` (acceleration speed ~0.6, flat profile unset, not left handed). `xkb_config` is not shipped: it is generated at run time (see below) |
| `com.system76.CosmicSettings.Shortcuts` (v1) | `custom` from `custom.in`: Super+Shift+S runs `cosmic-screenshot`, Alt+S runs `@HOME@/.local/bin/aura switcher` |
| `com.system76.CosmicTk` (v1) | `header_size` Compact; `interface_density` Compact; `icon_theme` "Papirus-Dark" |
| `com.system76.CosmicTheme.Mode` (v1) | `is_dark` true |
| `com.system76.CosmicTheme.Dark.Builder` and `.Light.Builder` (v2) | all 22 builder keys: accent `#6E22A8` (dark and light), frosted ExtremelyLow, gaps (0, 8), corner radii, spacing, palette, alpha map, tints |
| `com.system76.CosmicTheme.Dark` and `.Light` (v2) | all derived theme keys (background, primary, secondary, buttons, accent, palette, ...). Shipped so the theme applies without opening Settings |
| `com.system76.CosmicIdle` (v1) | `screen_off_time` None; `suspend_on_ac_time` None (idle actions disabled) |
| `com.system76.CosmicPortal` (v1) | `screenshot`: save to Clipboard, choice Rectangle (see seed-only note) |
| `com.system76.CosmicAppletTime` (v1) | `first_day_of_week` 6; `military_time` false |
| `com.system76.CosmicAppletAudio` (v1) | `show_media_controls_in_top_panel` false |
| `com.system76.CosmicTerm` (v1) | `show_headerbar` false |
| `com.system76.CosmicFiles` (v1) | `context_actions` (PeaZip: open, extract here, extract to folder, compress), `desktop`, `dialog`, `show_details`, `tab` (show hidden, list view) |
| `com.system76.CosmicAppList` (v1) | `enable_drag_source` true; `favorites` []; `filter_top_levels` None |

Three deviations from a pure copy:

- `CosmicComp/v1/xkb_config` is generated at run time from the system keyboard
  (`localectl status`: `X11 Layout`, `X11 Variant`, `X11 Options`), so the
  layout chosen in the EndeavourOS installer is kept (a layout list such as
  `latam,us` is passed through). Empty variant renders `""`, empty options
  render `None`, otherwise `Some("<options>")`; `"` and `\` are escaped. The key
  repeat of the reference host is kept (`repeat_delay` 600, `repeat_rate` 25).
  The RON is byte-exact with the file COSMIC writes (no trailing newline), so
  the reference host reports no change. When `localectl` is missing or reports
  no X11 layout, the file is left untouched and the module warns.

- `Shortcuts/v1/custom.in` replaces the home directory with `@HOME@` and is
  rendered with the real `$HOME` at apply time (`install_template`).
- `CosmicPortal/v1/screenshot` has `last_rectangle: None` (the live value is a
  resolution specific screen region). It is also seed-only: installed only when
  the file does not exist, because the portal rewrites it after every
  screenshot.

### Explicitly excluded

- `CosmicComp/v1/input_devices`: hardware specific, belongs to the opt-in wacom
  module.
- `CosmicSettings.Shortcuts/v1/system_actions`: owned by the kitty module.
- `CosmicTk` `interface_font` and `monospace_font` (and `*.bak.*`): there are
  no font keys, so COSMIC keeps its compiled default fonts.
- `CosmicFiles/v1/favorites`: contains a personal absolute path.
- `CosmicTheme.Dark/Light(.Builder)/v1/*`: stale keys from an older schema; COSMIC
  reads v2.
- Panels and dock (`CosmicPanel*`, `CosmicPanelButton`), `CosmicBackground`,
  `CosmicSettings.Wallpaper`, `CosmicSettings`, `CosmicSettings.WindowRules`
  (empty), and `io.github.crocodile.*` (applets module).

## Files and packages touched

- Every file under `files/cosmic/` is installed to `$HOME/.config/cosmic/<same
  relative path>` with mode 0644 (`.in` files are rendered, destination without
  `.in`). Keys not shipped are never modified or deleted.
- `$HOME/.config/cosmic/com.system76.CosmicComp/v1/xkb_config`, generated from
  the system keyboard (backed up first when it changes).
- Package: `papirus-icon-theme` (official), needed for `Papirus-Dark`.
- No services. cosmic-config watches the key files, so changes apply live; no
  COSMIC process is restarted.

## Hardware detection

none

## Idempotency check

Each key file is compared byte by byte (`install_file`); the rendered shortcut
and the generated `xkb_config` are compared after rendering. The seed-only key is skipped when present. A
second run reports "Nothing to change".

## Revert

- Restore any key from its `<key>.bak.<timestamp>` file (created next to the
  key before it was overwritten), or
- delete the shipped key files under `~/.config/cosmic/` to fall back to COSMIC
  defaults for those keys.
- `sudo pacman -Rns papirus-icon-theme` to remove the icon theme.

## Verification

- `./install.sh --only cosmic-settings --dry-run` reports "Nothing to change"
  after a real run.
- `rg -n '/home/' files/cosmic` prints nothing.
- `tests/test-xkb.sh` checks the `xkb_config` renderer and the `localectl` parser.
- `fd -t f 'font' files/cosmic` prints nothing.
- `shellcheck -x install.sh lib/common.sh modules/*.sh files/kitty/kitty-cosmic-colors.sh`
