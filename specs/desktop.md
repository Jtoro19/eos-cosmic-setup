# desktop

## Purpose

Turn an EndeavourOS install made **without a desktop** into a COSMIC desktop
with its graphical login. On a machine that already has COSMIC it changes
nothing.

## Source of truth

The reference host (COSMIC 1.11) and the user's own procedure for installing
COSMIC on a no-desktop EndeavourOS install.

## What the module does

1. If any package below is missing (first run on a fresh install), a full
   `pacman -Syu --noconfirm` first, so new packages match the system.
2. Installs the `cosmic` group from the sync database, minus members the
   reference host does not use: `cosmic-initial-setup` (a first-login wizard
   that would override this repo's settings), `cosmic-osk` and
   `cosmic-monitor`. Reading the group keeps new COSMIC components covered.
3. Installs the session base a desktop install normally brings: XWayland,
   PipeWire (pulse, alsa, jack, WirePlumber), BlueZ, NetworkManager,
   power-profiles-daemon, gnome-keyring, xdg-user-dirs, packagekit (COSMIC
   Store installs through it), cups, avahi, firewalld.
4. Disables other display managers if enabled (gdm, lightdm, sddm, lxdm, ly)
   and the live ISO's `pacman-init`, then enables `cosmic-greeter`.
5. Sets `graphical.target` as the default boot target.

Services such as NetworkManager, bluetooth, cups and firewalld are enabled by
the `services` module; GPU drivers by `drivers` (on a VM, mesa plus
`vulkan-swrast`).

## Ordering

`06-desktop.sh` runs after `pacman-conf` (multilib) and before everything that
configures COSMIC.

## Hardware detection

None here; see `drivers`.

## Idempotency check

`pacman -Qq` per package and `systemctl is-enabled` / `get-default` are
read-only. The full upgrade only runs when something is missing.

## Revert

`sudo systemctl disable cosmic-greeter`, `sudo systemctl set-default
multi-user.target`, and remove the packages if wanted. Reverting a desktop is
rarely useful; reinstalling is simpler.

## Verification

- After a reboot the machine shows the COSMIC login.
- `./install.sh --only desktop --dry-run` reports nothing to change on the
  reference host.
