# vesktop-mic

Opt-in (`MODULE_OPTIN=1`): run it with `./install.sh --only vesktop-mic`.

## Purpose

Stop Vesktop's WebRTC automatic gain control from lowering the system
microphone volume.

## Source of truth

`reference/resumen_arreglos_endeavouros.md` section 1 and the reference host:
a PipeWire rule matching `application.process.binary = "vesktop"` with the
`block-source-volume` quirk, plus `--disable-features=WebRtcAllowInputVolumeAdjustment`
in `~/.config/vesktop-flags.conf` (read by the `/usr/bin/vesktop` launcher).
The rule ships as `files/vesktop-mic/10-block-agc.conf`.

## Files and packages touched

- `~/.config/pipewire/pipewire-pulse.conf.d/10-block-agc.conf` (installed).
- Migration: the earlier hand-made `10-bloquear-agc.conf` in the same
  directory is backed up (`.bak.<timestamp>`, ignored by PipeWire because it
  does not end in `.conf`) and removed, so one rule file remains. Extra matches
  you added to the old file are preserved only in that backup.
- `~/.config/vesktop-flags.conf`: the flag line is appended if missing.
- On a rule change: `systemctl --user restart pipewire pipewire-pulse
  wireplumber`. Restart Vesktop afterwards (the flag also needs a Vesktop restart).

## Hardware detection

None. The module is skipped (with an info message) when Vesktop is not
installed (neither the `vesktop` package nor a `vesktop` command); the
Flatpak build is not covered. The process binary name Vesktop reports was
checked on the reference host with `pactl list source-outputs | grep
application.process.binary` and `pactl list clients`: it is `vesktop`.

To cover another app that also adjusts the microphone, add a line inside
`matches` in the installed file using the name that command prints, then restart
the audio stack.

## Idempotency check

`install_file` compares content, the migration only acts when the legacy
file exists, and `ensure_line` checks the flag line. The audio stack restarts
only when the rule file changed. A second run reports nothing to change.
On the reference host the first dry-run shows 2 changes (install the new file,
remove the legacy one); the flag line already exists.

## Revert

```bash
rm ~/.config/pipewire/pipewire-pulse.conf.d/10-block-agc.conf
systemctl --user restart pipewire pipewire-pulse wireplumber
```

Remove the flag line from `~/.config/vesktop-flags.conf` if wanted.

## Verification

- `./install.sh --only vesktop-mic --dry-run` reports nothing to change after
  applying.
- With Vesktop capturing: `wpctl get-volume @DEFAULT_AUDIO_SOURCE@` stays at its
  value (for example `Volume: 1.00`).

Optional manual steps, not automated because they depend on the hardware: set
the source volume (`wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 1.0`), save the
sound card state with `sudo alsactl store`, and turn off "Automatic gain
control" in Vesktop under Voice & Video.
