# clipboard

## Purpose

Keep clipboard contents on COSMIC (Wayland) after the application that copied
them closes. By default the clipboard dies with its source app.

## Source of truth

Captured from the reference host and `reference/portapapeles-cosmic.md`:

- `/etc/environment` contains `COSMIC_DATA_CONTROL_ENABLED=1`. COSMIC disables
  the wlr data-control protocol by default, and wl-clip-persist needs it.
  `/etc/environment` is used instead of the session `.desktop` file so package
  updates do not overwrite it.
- `~/.config/systemd/user/wl-clip-persist.service`, tied to
  `graphical-session.target`. COSMIC autostart (`~/.config/autostart`) proved
  unreliable for this, even with a delay, so a systemd user unit is used.

## Files and packages touched

- Packages: `wl-clipboard`, `wl-clip-persist`.
- `/etc/environment` (one line, via sudo).
- `~/.config/systemd/user/wl-clip-persist.service` (enabled).
- Removes a stale `~/.config/autostart/wl-clip-persist.desktop` if present.

## Hardware detection

None.

## Idempotency check

- The env line is only appended if missing (exact match).
- The unit is only installed if its bytes differ, then `daemon-reload` and
  `try-restart`. It is only enabled if not already enabled.

## Revert

- `systemctl --user disable --now wl-clip-persist.service`
- `rm ~/.config/systemd/user/wl-clip-persist.service && systemctl --user daemon-reload`
- `sudo sed -i '/^COSMIC_DATA_CONTROL_ENABLED=1$/d' /etc/environment` (or restore
  `/etc/environment.bak.<timestamp>`), then log out and back in.
- `sudo pacman -Rns wl-clip-persist` if wanted.

## Verification

- `systemctl --user is-active wl-clip-persist.service` prints `active`.
- `pgrep -a wl-clip-persist` shows the process.
- Copy text in an app, close the app, paste elsewhere: the text is still there.
- The env var requires a new login to take effect.
