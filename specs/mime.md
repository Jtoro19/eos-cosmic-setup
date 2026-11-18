# mime

## Purpose

Set the user's default applications in `~/.config/mimeapps.list`.

## Source of truth

`~/.config/mimeapps.list` on the reference host (Brave for web and HTML,
Vesktop for `discord://` links) plus the effective defaults reported by
`xdg-mime query default`: PDF opens in Brave and zip in PeaZip. Those two come
from desktop file order on the reference host, so they are pinned here to be
the same on every machine.

Not managed here:

- COSMIC apps (Files, Viewer, Player, Text Editor) are the defaults shipped by
  COSMIC's own `cosmic-mimeapps.list`; a fresh install already has them.
- The terminal (`cosmic-mimeapps.list`) belongs to the `kitty` module.
- `x-scheme-handler/claude-cli`: claude-code registers it on its first run.
- `mailto` keeps the system default.

## Mappings

| MIME type | Desktop entry |
|-----------|---------------|
| text/html, x-scheme-handler/http, https, about, unknown | brave-browser.desktop |
| application/pdf | brave-browser.desktop |
| application/zip | peazip-extract.desktop |
| x-scheme-handler/discord | vesktop.desktop |

A mapping is applied only when its desktop entry is installed (user, system or
Flatpak exports directories). Vesktop comes with `packages-media`; without that
group its line is skipped. The module runs after the package groups
(`75-mime.sh`).

## Files and packages touched

- `~/.config/mimeapps.list`, `[Default Applications]` section only, key by key
  (`ensure_ini_line ... replace`). Other entries are kept.
- No packages.

## Hardware detection

None.

## Idempotency check

Each line is checked in the `[Default Applications]` section; existing exact
lines are skipped, a different value for the same key is replaced.

## Revert

Restore `~/.config/mimeapps.list.bak.<timestamp>`, or delete the lines.

## Verification

- `xdg-mime query default application/pdf` prints `brave-browser.desktop`.
- `./install.sh --only mime --dry-run` reports nothing to change after the
  first run.
