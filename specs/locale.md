# locale

## Purpose

Apply the user's language, regional formats and keyboard layout on every
machine.

## Source of truth

The reference host:

- `/etc/locale.gen`: `en_US.UTF-8 UTF-8` and `es_CO.UTF-8 UTF-8` enabled.
- `/etc/locale.conf`: `LANG=en_US.UTF-8` (English interface) and every other
  `LC_*` category in `es_CO.UTF-8` (Colombian dates, numbers, money, paper,
  measurements). Shipped byte-exact as `files/locale/locale.conf`.
- Console keymap `us`; X11/XKB layout `us`, variant `altgr-intl`.
- Time zone `America/Bogota`.

The COSMIC session keyboard (`xkb_config`) is shipped by `cosmic-settings`;
this module covers the console and the greeter.

## Time zone

Not changed by default: the EndeavourOS installer already asks for the time
zone, and a machine may live elsewhere. Set `LOCALE_TZ` to force one, for
example `LOCALE_TZ=America/Bogota ./install.sh --only locale`. An unknown zone
fails the module with an error.

## Files and packages touched

- `/etc/locale.gen` (wanted lines uncommented, or appended if missing), then
  `locale-gen` when it changed.
- `/etc/locale.conf`.
- `localectl set-keymap` and `localectl set-x11-keymap` (they write
  `/etc/vconsole.conf` and `/etc/X11/xorg.conf.d/00-keyboard.conf`), only when
  the current values differ.
- `timedatectl set-timezone` only with `LOCALE_TZ`.

All via sudo; files are backed up first.

## Hardware detection

None.

## Ordering

`08-locale.sh` runs early, before packages are installed.

## Idempotency check

The rendered `locale.gen` and `locale.conf` are compared byte for byte; the
keymap, layout, variant and time zone are compared with `localectl status` and
`timedatectl show`.

## Revert

Restore `/etc/locale.gen.bak.<timestamp>` and `/etc/locale.conf.bak.<timestamp>`
and run `sudo locale-gen`; `sudo localectl set-keymap <map>` and
`sudo localectl set-x11-keymap <layout>` for the keyboard. Log out and back in.

## Verification

- `localectl status` shows `LANG=en_US.UTF-8`, the `LC_*` lines in
  `es_CO.UTF-8`, `VC Keymap: us`, `X11 Variant: altgr-intl`.
- `./install.sh --only locale --dry-run` reports nothing to change on the
  reference host.
