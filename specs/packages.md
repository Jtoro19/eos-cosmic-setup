# packages

Eight modules install the package set of the reference machine, split into a
default core group and seven opt-in groups.

## Purpose

Reproduce the explicit package set of the reference host on a fresh
EndeavourOS + COSMIC install. Everything is data: plain text lists under
`files/packages/`, read by one helper, so adding or removing a package is a
one-line edit.

## Source of truth

`pacman -Qqe` (explicit packages) and `pacman -Qqm` (foreign/AUR packages) on
the reference host, classified so that every explicit package is in exactly one
list or in the excluded table below. The lists live in
`files/packages/<group>.pacman` (official repos) and `files/packages/<group>.aur`
(AUR, needs `yay`). One package per line; `#` starts a comment; blank lines
are ignored.

## Modules and selection

| Module | Opt-in | Lists | Depends on |
|--------|--------|-------|------------|
| packages | no | core | none |
| packages-dev | yes | dev | packages |
| packages-gaming | yes | gaming | packages, pacman-conf (Steam is in `[multilib]`) |
| packages-media | yes | media | packages |
| packages-office | yes | office | packages |
| packages-printing | yes | printing | packages |
| packages-ai | yes | none (code, see below) | packages |
| packages-vmware | yes | vmware | packages |

`--all` runs only `packages` (core). Opt-in groups run when named:

```
./install.sh --all --only packages-dev,packages-gaming
./install.sh --only packages-ai --dry-run
```

`--all --only x` runs every default module plus `x` (and its dependencies).

## Files and packages touched

- No files are created or modified outside the package database.
- `install_package_list <group>` (in `lib/common.sh`) reads both lists, drops
  comments and blank lines, and calls `ensure_packages` (official) and
  `ensure_aur_packages` (AUR) with the missing packages only. `pacman -Qq`
  counts a package installed as a dependency as installed, so such packages
  are never reinstalled or marked explicit.
- AUR lists need `yay`. It is in the `core` list (EndeavourOS repo), so the
  `packages` module installs it first. If a group has missing AUR packages and
  `yay` is absent, the module logs an error and fails (only that module; its
  dependents are skipped). When nothing is missing, `yay` is not required.
- `packages-ai` is code, not a list: `detect_gpu_vendors` containing `amd`
  installs `ollama-rocm`; else `nvidia` installs `ollama-cuda`; else `ollama`.
  `ollama-rocm` and `ollama-cuda` depend on `ollama`, so the base package
  comes with them. `PACKAGES_AI_GPU_VENDORS` is a test-only override for
  `--dry-run` (an empty value simulates no GPU).
- Services are NOT enabled here (docker, cups, cups-browsed, libvirt,
  firewalld, bluetooth...). A later services module owns that. Installing
  `docker` or `cups` does not start them.

## Hardware detection

Only `packages-ai` (GPU vendor, above). Vendor drivers and firmware belong to
the `drivers` module and are excluded from every list.

## Idempotency check

Each module checks every package with `pacman -Qq` and acts only on missing
ones. A second run (or a host that already has everything) logs no change and
`--dry-run` reports "Nothing to change".

## Classification

Counts come from the reference host at the time of writing: 260 explicit
packages (`pacman -Qqe`), 14 foreign (`pacman -Qqm`).

Notes:

- `ripgrep` and `fd` are listed in core although the host has them only as
  dependencies: the user's rules mandate `rg` and `fd`. They count as installed
  when present. They are the only listed packages that are not explicit on the
  host, so lists hold 108 explicit packages + these 2 = 110 entries.
- `base-devel`, `git` and `rust` are also installed by the `applets` module
  (build prerequisites). They stay in `dev` as the user-facing group; the
  helpers skip what is installed.
- `libelectron` and `electron-castlab-bin` are installed as dependencies of
  `crunchyroll` (`Required By`), so they are not listed.
- Dependency-only packages (not explicit on the host) are never listed.

### core

| Group | Package | Source |
|-------|---------|--------|
| core | firefox | pacman |
| core | librewolf | pacman |
| core | bat | pacman |
| core | eza | pacman |
| core | fd | pacman |
| core | ripgrep | pacman |
| core | direnv | pacman |
| core | htop | pacman |
| core | glances | pacman |
| core | nvtop | pacman |
| core | duf | pacman |
| core | tldr | pacman |
| core | tree | pacman |
| core | plocate | pacman |
| core | pkgfile | pacman |
| core | inxi | pacman |
| core | hwinfo | pacman |
| core | mesa-utils | pacman |
| core | rsync | pacman |
| core | wget | pacman |
| core | unzip | pacman |
| core | unrar | pacman |
| core | bash-completion | pacman |
| core | neovim | pacman |
| core | nano | pacman |
| core | nano-syntax-highlighting | pacman |
| core | man-db | pacman |
| core | man-pages | pacman |
| core | which | pacman |
| core | whois | pacman |
| core | less | pacman |
| core | yay | pacman |
| core | downgrade | pacman |
| core | pacman-contrib | pacman |
| core | rebuild-detector | pacman |
| core | noto-fonts | pacman |
| core | noto-fonts-cjk | pacman |
| core | noto-fonts-emoji | pacman |
| core | noto-fonts-extra | pacman |
| core | ttf-dejavu | pacman |
| core | ttf-liberation | pacman |
| core | ttf-opensans | pacman |
| core | ttf-bitstream-vera | pacman |
| core | cantarell-fonts | pacman |
| core | peazip | pacman |
| core | gst-libav | pacman |
| core | gst-plugin-pipewire | pacman |
| core | gst-plugin-va | pacman |
| core | gst-plugins-bad | pacman |
| core | gst-plugins-ugly | pacman |
| core | pavucontrol | pacman |
| core | gnome-keyring | pacman |
| core | xdg-user-dirs | pacman |
| core | xdg-utils | pacman |
| core | brave-bin | aur |

### dev

| Group | Package | Source |
|-------|---------|--------|
| dev | base-devel | pacman |
| dev | git | pacman |
| dev | go | pacman |
| dev | rust | pacman |
| dev | python | pacman |
| dev | python-pillow | pacman |
| dev | python-pyqt5 | pacman |
| dev | python-reportlab | pacman |
| dev | uv | pacman |
| dev | docker | pacman |
| dev | docker-buildx | pacman |
| dev | docker-compose | pacman |
| dev | mariadb | pacman |
| dev | meld | pacman |
| dev | just | pacman |
| dev | android-tools | pacman |
| dev | android-udev | pacman |
| dev | shellcheck | pacman |
| dev | visual-studio-code-bin | aur |
| dev | claude-code | aur |
| dev | gentle-ai | aur |
| dev | engram-bin | aur |

### gaming

| Group | Package | Source |
|-------|---------|--------|
| gaming | steam | pacman |
| gaming | gamemode | pacman |
| gaming | mangohud | pacman |

### media

| Group | Package | Source |
|-------|---------|--------|
| media | gimp | pacman |
| media | krita | pacman |
| media | spotify-launcher | pacman |
| media | libdvdcss | pacman |
| media | libopenraw | pacman |
| media | libgsf | pacman |
| media | vesktop | aur |
| media | crunchyroll | aur |
| media | iriunwebcam-bin | aur |

### office

| Group | Package | Source |
|-------|---------|--------|
| office | libreoffice-fresh | pacman |
| office | obsidian | pacman |
| office | aspell | pacman |

### printing

| Group | Package | Source |
|-------|---------|--------|
| printing | cups | pacman |
| printing | cups-browsed | pacman |
| printing | cups-filters | pacman |
| printing | cups-pdf | pacman |
| printing | foomatic-db | pacman |
| printing | foomatic-db-engine | pacman |
| printing | foomatic-db-gutenprint-ppds | pacman |
| printing | foomatic-db-nonfree | pacman |
| printing | foomatic-db-nonfree-ppds | pacman |
| printing | foomatic-db-ppds | pacman |
| printing | ghostscript | pacman |
| printing | gsfonts | pacman |
| printing | gutenprint | pacman |
| printing | hplip | pacman |
| printing | sane | pacman |
| printing | system-config-printer | pacman |

### vmware

| Group | Package | Source |
|-------|---------|--------|
| vmware | vmware-workstation | aur |
| vmware | vmware-keymaps | aur |

### ai

| Group | Package | Source |
|-------|---------|--------|
| ai | ollama-rocm (host build; `ollama-cuda` on NVIDIA, `ollama` otherwise) | pacman, chosen in code |

## Excluded packages

Explicit on the host but not listed anywhere: 151 packages. "Assumed present on
EndeavourOS" means a fresh EndeavourOS + COSMIC install already ships it, so
listing it would add nothing and risk conflicts.

| Package | Reason |
|---------|--------|
| knime-desktop | not wanted (removed at the user's request) |
| accountsservice | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| alsa-firmware | hardware-specific driver, firmware or microcode (drivers module or this machine only) |
| alsa-plugins | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| alsa-utils | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| amd-ucode | hardware-specific driver, firmware or microcode (drivers module or this machine only) |
| b43-fwcutter | hardware-specific driver, firmware or microcode (drivers module or this machine only) |
| base | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| bind | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| bluez | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| bluez-utils | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| btrfs-progs | filesystem, storage or disk tool (assumed present on EndeavourOS) |
| cosmic-applets | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-app-library | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-bg | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-comp | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-ext-applet-now-playing-extended-git | other module of this repo |
| cosmic-files | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-greeter | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-idle | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-launcher | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-notifications | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-osd | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-panel | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-player | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-randr | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-screenshot | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-session | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-settings | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-settings-daemon | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-store | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-terminal | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-text-editor | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-viewer | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-wallpapers | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cosmic-workspaces | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| cryptsetup | filesystem, storage or disk tool (assumed present on EndeavourOS) |
| device-mapper | filesystem, storage or disk tool (assumed present on EndeavourOS) |
| dialog | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| diffutils | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| dmidecode | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| dmraid | filesystem, storage or disk tool (assumed present on EndeavourOS) |
| dnsmasq | future kvm module |
| dosfstools | filesystem, storage or disk tool (assumed present on EndeavourOS) |
| dracut | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| e2fsprogs | filesystem, storage or disk tool (assumed present on EndeavourOS) |
| edk2-ovmf | future kvm module |
| efibootmgr | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| efitools | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| endeavouros-branding | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| endeavouros-keyring | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| endeavouros-mirrorlist | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| eos-apps-info | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| eos-dracut | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| eos-hooks | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| eos-hwtool | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| eos-log-tool | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| eos-packagelist | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| eos-quickstart | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| eos-rankmirrors | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| ethtool | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| exfatprogs | filesystem, storage or disk tool (assumed present on EndeavourOS) |
| ex-vi-compat | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| f2fs-tools | filesystem, storage or disk tool (assumed present on EndeavourOS) |
| fastfetch | other module of this repo |
| firewall-applet | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| firewalld | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| git-lfs | other module of this repo |
| grub | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| haveged | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| hdparm | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| hwdetect | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| inetutils | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| iptables | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| iwd | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| jfsutils | filesystem, storage or disk tool (assumed present on EndeavourOS) |
| jq | other module of this repo |
| kitty | other module of this repo |
| libinput-tools | future wacom module |
| libvirt | future kvm module |
| linux | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| linux-firmware | hardware-specific driver, firmware or microcode (drivers module or this machine only) |
| linux-headers | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| logrotate | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| lsb-release | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| lsscsi | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| lswt | other module of this repo |
| lvm2 | filesystem, storage or disk tool (assumed present on EndeavourOS) |
| mdadm | filesystem, storage or disk tool (assumed present on EndeavourOS) |
| modemmanager | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| mpv | other module of this repo |
| mtools | filesystem, storage or disk tool (assumed present on EndeavourOS) |
| netctl | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| networkmanager | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| networkmanager-openconnect | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| networkmanager-openvpn | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| nfs-utils | filesystem, storage or disk tool (assumed present on EndeavourOS) |
| nilfs-utils | filesystem, storage or disk tool (assumed present on EndeavourOS) |
| nss-mdns | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| ntfs-3g | filesystem, storage or disk tool (assumed present on EndeavourOS) |
| ntp | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| openssh | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| os-prober | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| packagekit | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| papirus-icon-theme | other module of this repo |
| perl | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| pipewire-alsa | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| pipewire-jack | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| pipewire-pulse | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| poppler-glib | dependency of a listed package (pulled in automatically) |
| power-profiles-daemon | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| python-defusedxml | dependency of a listed package (pulled in automatically) |
| python-jinja | dependency of a listed package (pulled in automatically) |
| python-packaging | dependency of a listed package (pulled in automatically) |
| qemu-desktop | future kvm module |
| qt5ct | other module of this repo |
| reflector | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| reflector-simple | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| rtkit | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| sg3_utils | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| smartmontools | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| s-nail | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| sof-firmware | hardware-specific driver, firmware or microcode (drivers module or this machine only) |
| sudo | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| swtpm | future kvm module |
| sysfsutils | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| systemd-sysvcompat | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| texinfo | dependency of a listed package (pulled in automatically) |
| upower | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| usb_modeswitch | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| usbutils | base system, kernel or toolchain default (assumed present on EndeavourOS) |
| virt-manager | future kvm module |
| virt-viewer | future kvm module |
| vulkan-radeon | hardware-specific driver, firmware or microcode (drivers module or this machine only) |
| vulkan-swrast | hardware-specific driver, firmware or microcode (drivers module or this machine only) |
| welcome | EndeavourOS branding, tooling or hooks (assumed present on EndeavourOS) |
| wireless-regdb | hardware-specific driver, firmware or microcode (drivers module or this machine only) |
| wireplumber | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| wl-clipboard | other module of this repo |
| wl-clip-persist | other module of this repo |
| xdg-desktop-portal-cosmic | COSMIC session package (assumed present on EndeavourOS COSMIC) |
| xf86-input-libinput | Xorg/X11 base bits (assumed present on EndeavourOS) |
| xfsprogs | filesystem, storage or disk tool (assumed present on EndeavourOS) |
| xl2tpd | networking, bluetooth or audio stack (assumed present on EndeavourOS) |
| xorg-server | Xorg/X11 base bits (assumed present on EndeavourOS) |
| xorg-xdpyinfo | Xorg/X11 base bits (assumed present on EndeavourOS) |
| xorg-xinit | Xorg/X11 base bits (assumed present on EndeavourOS) |
| xorg-xinput | Xorg/X11 base bits (assumed present on EndeavourOS) |
| xorg-xkill | Xorg/X11 base bits (assumed present on EndeavourOS) |
| xorg-xrandr | Xorg/X11 base bits (assumed present on EndeavourOS) |
| xterm | base system, kernel or toolchain default (assumed present on EndeavourOS) |

## Accounting

108 explicit packages in lists + 1 (`ollama-rocm`, handled in code) + 151
excluded = 260 = `pacman -Qqe`. The per-list numbers can be recomputed with:

```
for f in files/packages/*; do echo "$f $(rg -vc '^(#|$)' "$f")"; done
```

## Revert

Removing packages can break other software; review the list first, and note
that dependencies shared with other groups or modules may be needed.

```
# example for one group; double-check before running
sudo pacman -Rns $(rg -v '^(#|$)' files/packages/gaming.pacman)
yay -Rns $(rg -v '^(#|$)' files/packages/media.aur)
```

Never run this for `core` unless you mean it. Packages that other packages
still need are refused by pacman, which is the safe outcome.

## Verification

- `shellcheck -x install.sh lib/common.sh modules/*.sh` is clean.
- `./install.sh --list` shows `packages` (opt-in no) and the seven
  `packages-*` modules (opt-in yes).
- `./install.sh --only packages,packages-dev,packages-gaming,packages-media,packages-office,packages-printing,packages-ai,packages-vmware --dry-run`
  on the reference host reports "Nothing to change".
- On a fresh machine: run it for real, then `--dry-run` again and expect
  "Nothing to change".
- Every listed official package exists: `pacman -Si <pkg>`; every AUR package
  is foreign: `pacman -Qm <pkg>`.
