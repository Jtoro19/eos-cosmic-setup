# kvm

Opt-in (`MODULE_OPTIN=1`): run it with `./install.sh --only kvm`.

## Purpose

Set up virtual machines with KVM/QEMU, libvirt and virt-manager: packages,
the libvirt daemon, user groups and the default NAT network.

## Source of truth

`reference/kvm-setup-cosmic.md` (sections 2 to 4) and the reference host: the
packages below installed, `libvirtd` enabled, the user in the `libvirt` and
`kvm` groups, and the `default` network active with autostart. Nothing is
shipped under `files/`.

## Files and packages touched

- Packages: `qemu-desktop libvirt virt-manager virt-viewer dnsmasq edk2-ovmf
  swtpm`.
- Unit: `libvirtd.service` (enabled and started).
- Groups: `libvirt` and `kvm` (re-login needed).
- libvirt state: the `default` network (defined if missing, autostart on,
  started). `/etc/libvirt/network.conf` is never modified.

## Hardware detection

- The module checks `/proc/cpuinfo` for the `svm` (AMD-V) or `vmx` (VT-x) flag.
  Without it, it warns to enable SVM/VT-x in the firmware and returns without
  installing anything.
- `iptables` conflict: when some package is missing, the legacy `iptables`
  package is installed and nothing provides `iptables-nft`, libvirt's install
  would stop on pacman's "replace iptables?" prompt, which `--noconfirm`
  answers "no". The module then runs
  `pacman -S --needed --noconfirm --ask 4 iptables-nft` first. `4` is the
  `ALPM_QUESTION_CONFLICT_PKG` bit (see `alpm.h`): it answers yes to "remove
  the conflicting package?" for that one transaction. Current `iptables`
  packages already provide `iptables-nft`, so the step is normally skipped
  (as on the reference host).

## Idempotency check

All checks are read-only: `pacman -Qq`, `systemctl is-enabled`, `id -nG` and
`virsh -c qemu:///system net-info default` (works without sudo for libvirt group
members). A second run reports nothing to change. If the network state cannot
be read (fresh machine, daemon down, no group yet), it counts as "needs
action": a real run retries with sudo, a dry-run reports the autostart and
start changes.

Firewalld pitfall: if `net-start` fails because firewalld has no `libvirt`
zone, the module restarts firewalld then libvirtd and retries once. If it still
fails it only warns and points to the nftables backend fix in the guide
(`firewall_backend = "nftables"` in `/etc/libvirt/network.conf`); that edit is
left to the user.

## Revert

```bash
sudo virsh net-autostart --disable default
sudo systemctl disable --now libvirtd.service
sudo gpasswd -d "$USER" libvirt && sudo gpasswd -d "$USER" kvm
sudo pacman -Rns qemu-desktop libvirt virt-manager virt-viewer swtpm edk2-ovmf
```

Review the package removal first: `dnsmasq` may be used by other software.

## Verification

- `./install.sh --only kvm --dry-run` reports nothing to change on the
  reference host.
- `virsh -c qemu:///system net-list --all` shows `default` active with
  autostart `yes`.
- `virt-host-validate qemu` shows `PASS` for KVM.
