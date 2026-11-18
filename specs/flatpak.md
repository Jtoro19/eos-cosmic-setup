# flatpak

## Purpose

Install Flatpak and add the flathub remote system-wide, so the package groups
can install their Flatpak apps.

## Source of truth

The reference host has one system remote, `flathub`
(`https://dl.flathub.org/repo/`), no user-scope remotes, and three system apps:
OBS Studio, Kdenlive and ProtonUp-Qt.

## Where the apps go

The apps are not installed by this module. They live in the package group
lists so a machine only gets them with the matching group:

- `files/packages/media.flatpak`: `com.obsproject.Studio`, `org.kde.kdenlive`
  (module `packages-media`).
- `files/packages/gaming.flatpak`: `net.davidotek.pupgui2` (module
  `packages-gaming`).

Both groups depend on this module. `install_package_list` reads the
`.flatpak` list and calls `ensure_flatpaks`, which installs only the missing
apps with `flatpak install --system -y --noninteractive flathub`.

The `dark-mode` module uses the same helpers for the adw-gtk3-dark theme
runtime.

## Files and packages touched

- Package `flatpak`.
- System remote `flathub` (via sudo).

## Hardware detection

None.

## Idempotency check

`pacman -Qq flatpak`, `flatpak remotes --system` and `flatpak info --system
<app>` are read-only; present items are skipped.

## Revert

`sudo flatpak uninstall --system <app>` for an app,
`sudo flatpak remote-delete --system flathub` for the remote (after removing
its apps), `sudo pacman -Rns flatpak`.

## Verification

- `./install.sh --only flatpak --dry-run` reports nothing to change on the
  reference host.
- `flatpak remotes --system` lists `flathub`.
