# panel

## Purpose

Reproduce the COSMIC top panel exactly as in `reference/screenshots/panel-applets.png`.

## Source of truth

Captured byte-exact from the reference host, one cosmic-config key per file:

- `com.system76.CosmicPanel/v1/entries` = `["Panel"]`. Only the top panel is
  active; the Dock is not listed, so it stays off.
- `com.system76.CosmicPanel.Panel/v1/*` (25 keys): anchor `Top`, size `XS`,
  output `All`, autohide `Never`, expand to edges, no gaps or radius.
  - `plugins_wings` start: Workspace Icons
    (`io.github.crocodile.cosmic-ext-applet-workspace-icons`).
  - `plugins_center`: Now Playing (`com.github.DiegoMMR.CosmicExtAppletNowPlaying`).
  - `plugins_wings` end, in order: Date, Time & Calendar; Lock Keys; Notifications
    Tray (StatusArea); Tiling; Sound; Bluetooth; Network; Power & Battery;
    Notifications Center; User Session (Power).

No key contains a path, so nothing is templated.

## Files and packages touched

- `~/.config/cosmic/com.system76.CosmicPanel/v1/entries`
- `~/.config/cosmic/com.system76.CosmicPanel.Panel/v1/*`
- No packages. Depends on the `applets` module so the three community applets
  exist before the panel references them.

## Hardware detection

None. `output: All` puts the panel on every monitor, so no output name is
needed.

## Idempotency check

Each key file is installed only when its bytes differ (`install_file`).
cosmic-panel watches these files and reloads live; no restart is done.

## Revert

Restore the `<key>.bak.<timestamp>` files, or delete the shipped key files to
fall back to the COSMIC default panel and dock. Changes apply live.

## Verification

- `./install.sh --only panel --dry-run` reports nothing to change on the
  reference host.
- After login, Settings > Desktop > Panel > Applets matches
  `panel-applets.png`.
