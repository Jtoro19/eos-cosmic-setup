# services

## Purpose

Enable the system services the desktop relies on, and the services and groups
that belong to the optional package groups, but only for what is installed.

## Source of truth

Enabled units on the reference host (`systemctl is-enabled`): NetworkManager,
bluetooth, firewalld, power-profiles-daemon, systemd-timesyncd, fstrim.timer,
avahi-daemon, cups, docker, mariadb, sshd, vmware-networks,
vmware-usbarbitrator. The user is in the `docker` and `adbusers` groups.

## What the module does

- Desktop services, each only if its unit file exists: `NetworkManager`,
  `bluetooth`, `firewalld`, `power-profiles-daemon`, `systemd-timesyncd`,
  `fstrim.timer`, `avahi-daemon`.
- Services from optional groups, again only if installed: `cups`
  (packages-printing), `docker` (packages-dev), `vmware-networks` and
  `vmware-usbarbitrator` (packages-vmware), `mariadb` (packages-dev). MariaDB's
  data directory is initialized with `mariadb-install-db` before its first
  start, because the service fails to start without it.
- `sshd` only with `SERVICES_SSHD=1`. Exposing an SSH server is a per-machine
  decision, so it is not on by default even though the reference host has it.
- Groups: `docker` when docker is installed, `adbusers` when the group exists
  (created by `android-udev`). Group changes need a new login.

The module only enables and starts. It never disables or stops a unit, so
running it on a machine with extra services leaves them alone.

Not handled here: the display manager (the EndeavourOS installer enables
cosmic-greeter), `libvirtd` and the `libvirt`/`kvm` groups (the opt-in `kvm`
module), and timers the reference host does not use (`paccache`, `reflector`).

## Hardware detection

None. Every unit is conditional on its unit file existing, so nothing depends
on the hardware or on which optional groups were installed.

## Idempotency check

`systemctl is-enabled` and `id -nG` are read-only checks; enabled units and
existing memberships are skipped.

## Revert

`sudo systemctl disable --now <unit>` for any unit, and
`sudo gpasswd -d "$USER" <group>` for a group.

## Verification

- `./install.sh --only services --dry-run` reports nothing to change on the
  reference host.
- `systemctl is-enabled NetworkManager bluetooth fstrim.timer` prints `enabled`.
