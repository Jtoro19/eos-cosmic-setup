# audio-resync

## Purpose

Work around a COSMIC bug where the panel sound applet and Settings > Sound
show "No device selected" with an empty device list, so their volume sliders
do nothing, while PipeWire, pavucontrol and `wpctl` keep working. Upstream:
pop-os/cosmic-settings-daemon#193 (the daemon does not pick up the PipeWire
devices until it is restarted). Seen on the reference host with
cosmic-applets/cosmic-settings 1.11.0, PipeWire 1.6.11 and WirePlumber 0.5.19,
also right after restarting the audio stack.

## Source of truth

The reference host: restarting `cosmic-settings-daemon` and then
`cosmic-panel` brings the devices back in the applet. The script ships as
`files/audio-resync/cosmic-audio-resync` and the login entry as
`files/audio-resync/cosmic-audio-resync.desktop.in`.

## Files and packages touched

- `~/.local/bin/cosmic-audio-resync` (installed, 0755): waits `RESYNC_DELAY`
  seconds (default 5), kills `cosmic-settings-daemon`, starts it again with
  `setsid` only when the session did not respawn it, then kills `cosmic-panel`
  (cosmic-session respawns it with its applets; killing only
  `cosmic-applet-audio` leaves the applet missing from the panel).
- `~/.config/autostart/cosmic-audio-resync.desktop` (rendered from the
  template with `@HOME@`). XDG autostart, not a systemd user unit: the daemon
  it starts needs the full session environment, and a process started from a
  oneshot unit would be killed with the unit's cgroup.
- Migration: the hand-made `~/.local/bin/fix-cosmic-audio.sh` and
  `~/.config/autostart/fix-cosmic-audio.desktop` are backed up
  (`.bak.<timestamp>`, the autostart backup is ignored because it does not end
  in `.desktop`) and removed.
- No packages.

## Hardware detection

None. The script exits without doing anything when `cosmic-settings-daemon`
is not installed.

## Idempotency check

`install_file` and `install_template` compare content, and the migration only
acts when the legacy files exist. A second run reports nothing to change.

## Revert

Remove this module once COSMIC ships the fix:

```bash
rm ~/.local/bin/cosmic-audio-resync ~/.config/autostart/cosmic-audio-resync.desktop
```

## Verification

- `./install.sh --only audio-resync --dry-run` reports nothing to change after
  applying.
- After login, the sound applet lists the output and input devices (for
  example "Headphones - Built-in Audio" and "Internal Microphone - Built-in
  Audio"), and moving its microphone slider changes
  `wpctl get-volume @DEFAULT_AUDIO_SOURCE@`.
- By hand, after restarting PipeWire: `RESYNC_DELAY=0 ~/.local/bin/cosmic-audio-resync`.
