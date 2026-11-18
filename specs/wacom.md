# wacom

Opt-in (`MODULE_OPTIN=1`): run it with `./install.sh --only wacom`.

## Purpose

Work around the cosmic-comp bug (cosmic-comp#2687) where a Wacom tablet is
silently ignored on machines without an internal display, by mapping each
tablet device to an output in the COSMIC compositor config.

## Source of truth

`reference/wacom-intuos-bt-s.md`. The reference machine is a desktop with one
HDMI monitor and a Wacom Intuos BT S, with this file:

```
{
    "<device name>": (state: Enabled, map_to_output: Some("<output>")),
}
```

Nothing is shipped under `files/`: device and output names are detected.

## Files and packages touched

- Packages: `libwacom`, `libinput-tools`.
- File: `~/.config/cosmic/com.system76.CosmicComp/v1/input_devices` (a RON map,
  not JSON), written through a temp file and `install_file` (backup first).
  A log out and back in may be needed the first time the file is created,
  because the hot reload can miss a brand new file.

## Hardware detection

- Tablet names come from `/proc/bus/input/devices`: lines `N: Name="Wacom ..."`
  whose name ends in ` Pen`, ` Pad`, ` Finger`, ` Touch` or ` Stylus`, deduplicated.
  This is the name the kernel gives the input node, which is what the compositor
  keys on (`libwacom-list-local-devices` prints the model name instead, which
  does not match). No tablet connected: the module logs it and does nothing.
- `cosmic-randr list` prints output names as the unindented lines
  (`<name> (enabled)`), with ANSI colors even when piped. If any output matches
  `eDP-*`, `LVDS-*` or `DSI-*` the machine has an internal display, the bug does
  not apply and nothing is mapped, unless `WACOM_FORCE=1`.
- Target output: the first enabled output, or `WACOM_OUTPUT=<name>`. Without a
  COSMIC session `cosmic-randr` fails: the module warns and skips unless
  `WACOM_OUTPUT` is set. A wrong output name is silently ignored by COSMIC,
  which is why the name is read from `cosmic-randr` and not guessed.

## Idempotency check

The module merges into the file and never overwrites it. It expects the format
COSMIC writes: `{`, one entry per line, `}`. For each detected device: an
existing entry has only its `state` set to `Enabled` and `map_to_output` set
to the target output (other fields and unrelated devices are kept); a missing
entry is appended before the closing brace. If the result equals the file,
nothing happens. A file with another shape (multi-line entries, no closing
brace, JSON) is left untouched with a warning. The merge function is
unit-tested (missing file, unchanged, replaced, unrelated kept, appended,
malformed).

If you replace or move the monitor, rerun the module (or edit
`map_to_output`) so the output name follows.

## Revert

Restore `input_devices.bak.<timestamp>` next to the file, or delete the
tablet entries. Keep the file while the upstream bug is open; COSMIC 1.10
adds a GUI setting for tablet mapping and the file can then be removed.

## Verification

- With a tablet connected: `./install.sh --only wacom --dry-run` reports
  nothing to change once the mapping is in place.
- Moving the pen moves the cursor. Pressure depends on the compositor's
  tablet protocol support (test in Krita).
- Without a tablet connected the module reports "no Wacom tablet connected".
