# mic-agc

## Purpose

Stop browsers and Electron apps (Google Meet, Discord, Zoom, Teams...) from
moving the system microphone volume with their WebRTC automatic gain control,
so the microphone stays at the level set in the COSMIC sound applet.

## Source of truth

The reference host: a PipeWire rule in
`~/.config/pipewire/pipewire-pulse.conf.d/` that applies the
`block-source-volume` quirk to the matched clients. It ships as
`files/mic-agc/20-block-mic-agc.conf`. Vesktop is left to the `vesktop-mic`
module (its own rule and Chromium flag); the two files do not conflict because
PipeWire appends `pulse.rules` arrays from every `conf.d` fragment.

## Files and packages touched

- `~/.config/pipewire/pipewire-pulse.conf.d/20-block-mic-agc.conf` (installed).
- Migration: the earlier hand-made `99-block-mic-agc.conf` in the same
  directory is backed up (`.bak.<timestamp>`, ignored by PipeWire because it
  does not end in `.conf`) and removed, so one rule file remains. Extra
  matches you added to the old file are preserved only in that backup.
- On a rule change, when the user PipeWire is running:
  `systemctl --user restart pipewire pipewire-pulse wireplumber`. Otherwise the
  rule applies at the next login.
- No packages.

## Hardware detection

None. The rule matches the `application.process.binary` of the client with an
anchored regex: `chrome`, `chromium`, `brave`, `vivaldi`, `firefox`,
`librewolf`, `Discord`, `discord`, `electron`, `zoom`, `teams-for-linux`,
`slack`. Apps not in the list keep their behavior. The COSMIC sound applet,
pavucontrol and `wpctl` are not matched, so they still set the volume.

To cover another app, read its binary name while it is capturing with
`pactl list source-outputs | grep application.process.binary`, add it inside
the regex in the installed file and restart the audio stack.

## Idempotency check

`install_file` compares content and the migration only acts when the legacy
file exists. The audio stack restarts only when the rule file changed. A
second run reports nothing to change.

## Revert

```bash
rm ~/.config/pipewire/pipewire-pulse.conf.d/20-block-mic-agc.conf
systemctl --user restart pipewire pipewire-pulse wireplumber
```

## Verification

- `./install.sh --only mic-agc --dry-run` reports nothing to change after
  applying.
- With a call open in the browser (for example Google Meet in Brave), while
  talking: `wpctl get-volume @DEFAULT_AUDIO_SOURCE@` stays at the value set in
  the applet (for example `Volume: 0.47`).
- Restarting PipeWire can trigger the COSMIC applet bug handled by
  `audio-resync` ("No device selected"); run
  `RESYNC_DELAY=0 ~/.local/bin/cosmic-audio-resync` or log in again.
