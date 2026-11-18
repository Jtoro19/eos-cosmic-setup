# eos-cosmic-setup

Turns a fresh EndeavourOS install (with COSMIC, or with no desktop at all) into a configured desktop with one
command. It is a set of small, idempotent bash modules that detect CPU and GPU
vendor at run time, so the same repository works across machines.

**New machine?** Follow [INSTALL.md](INSTALL.md) step by step.

## Requirements

- EndeavourOS, installed with COSMIC or with no desktop (the `desktop` module installs COSMIC)
- bash
- sudo (the installer refuses to run as root and calls sudo where needed)
- yay (only for modules that install AUR packages)

## Usage

```bash
./install.sh --list                    # list modules
./install.sh --all --dry-run           # show what would change, apply nothing
./install.sh --all                     # run all non-opt-in modules
./install.sh --only drivers            # one module plus its dependencies
./install.sh --only drivers,kitty      # comma-separated list
./install.sh --only kvm --only wacom   # repeatable
./install.sh --all --only kvm          # all defaults plus an opt-in module
```

`--dry-run` shows every change without applying it. Whenever a file is
modified, the original is first saved as `<file>.bak.<timestamp>`
(`YYYYmmdd-HHMMSS`). Running a module twice changes nothing the second time.

**Type the password once.** A real run asks for the sudo password at the start
(`sudo -v`) and keeps it valid in the background, so the rest runs unattended;
if the password is wrong the installer stops before changing anything. Every
step is non-interactive (`pacman --noconfirm`, `yay --sudoloop`, `flatpak -y`,
`GIT_TERMINAL_PROMPT=0`, stdin closed). A module stops at its first failed
command and the run ends with the list of failed modules and a non-zero exit.

**Log.** Every run that executes modules (also `--dry-run`) copies all output
to `${XDG_CACHE_HOME:-~/.cache}/eos-cosmic-setup/install-<YYYYmmdd-HHMMSS>.log`
and prints that path at the start and in the summary. The terminal keeps its
colors; the log has them stripped. Output goes through a pipe, so tools such as
pacman show plain instead of animated progress.

**Tests.** `tests/run-tests.sh` runs every `tests/test-*.sh` (errexit, sudo
handling, the COSMIC keyboard renderer). They use fake modules and a fake
`sudo`, need no privileges and change nothing on the machine.

See `modules/README.md` for the module contract and `specs/README.md` for the
spec template.

## Modules

Modules run in file-name order (`modules/NN-name.sh`). Opt-in modules only run
when named with `--only`.

| Module | Opt-in | What it does | How to revert |
|--------|--------|--------------|---------------|
| drivers | no | CPU microcode (amd-ucode / intel-ucode) and GPU drivers (mesa, Vulkan, VA-API) chosen by detected vendor (mesa + vulkan-swrast on VMs); NVIDIA via nvidia-inst | `sudo pacman -Rns` the vendor packages it installed (listed in `specs/drivers.md`); keep mesa |
| desktop | no | COSMIC desktop and cosmic-greeter for a no-desktop install: full upgrade on first run, the `cosmic` group (minus initial-setup, osk, monitor), PipeWire, BlueZ, NetworkManager, packagekit, cups, avahi, firewalld; disables other display managers; graphical boot target | `sudo systemctl disable cosmic-greeter`, `sudo systemctl set-default multi-user.target` (details in `specs/desktop.md`) |
| pacman-conf | no | `/etc/pacman.conf`: Color, ILoveCandy, VerbosePkgLists, ParallelDownloads = 5, and the multilib repository (full upgrade when multilib is newly enabled) | Restore `/etc/pacman.conf.bak.<timestamp>` (details in `specs/pacman-conf.md`) |
| packages | no | Core everyday packages: browsers (Brave, Firefox, LibreWolf), CLI tools (bat, eza, fd, ripgrep, neovim...), fonts, codecs, PeaZip, yay; lists in `files/packages/core.*` | `sudo pacman -Rns $(rg -v '^(#|$)' files/packages/core.pacman)` (and `yay -Rns` for the `.aur` list); review first (details in `specs/packages.md`) |
| packages-dev | yes | Development: base-devel, git, Go, Rust, Python, uv, Docker, MariaDB, VS Code, Claude Code, Android tools | `sudo pacman -Rns $(rg -v '^(#|$)' files/packages/dev.pacman)` (and `yay -Rns` for the `.aur` list); review first (details in `specs/packages.md`) |
| packages-gaming | yes | Gaming: Steam, GameMode, MangoHud, ProtonUp-Qt (Flatpak) (needs multilib) | `sudo pacman -Rns $(rg -v '^(#|$)' files/packages/gaming.pacman)` (and `yay -Rns` for the `.aur` list); review first (details in `specs/packages.md`) |
| packages-media | yes | Media and creative: GIMP, Krita, Spotify, Vesktop, Crunchyroll, IriunWebcam, OBS and Kdenlive (Flatpak) | `sudo pacman -Rns $(rg -v '^(#|$)' files/packages/media.pacman)` (and `yay -Rns` for the `.aur` list); review first (details in `specs/packages.md`) |
| packages-office | yes | Office: LibreOffice, Obsidian | `sudo pacman -Rns $(rg -v '^(#|$)' files/packages/office.pacman)` (and `yay -Rns` for the `.aur` list); review first (details in `specs/packages.md`) |
| packages-printing | yes | Printing and scanning: CUPS, HPLIP, Gutenprint, SANE; services not enabled | `sudo pacman -Rns $(rg -v '^(#|$)' files/packages/printing.pacman)` (and `yay -Rns` for the `.aur` list); review first (details in `specs/packages.md`) |
| packages-ai | yes | Ollama build by GPU vendor: ollama-rocm (AMD), ollama-cuda (NVIDIA), else ollama | `sudo pacman -Rns ollama-rocm` (or the build you got); review first (details in `specs/packages.md`) |
| packages-vmware | yes | VMware Workstation and keymaps (AUR) | `yay -Rns $(rg -v '^(#|$)' files/packages/vmware.aur)`; review first (details in `specs/packages.md`) |
| locale | no | English UI (`en_US`) with Colombian formats (`es_CO`), keyboard layout kept as chosen in the EndeavourOS installer; time zone only with `LOCALE_TZ=<zone>` | Restore the `/etc/locale.gen` and `/etc/locale.conf` backups, `sudo locale-gen` (details in `specs/locale.md`) |
| services | no | Enables installed services only: NetworkManager, bluetooth, firewalld, power profiles, timesyncd, fstrim, avahi; cups, docker, mariadb, VMware when their group is installed; sshd only with `SERVICES_SSHD=1`; docker/adbusers groups. Never disables anything | `sudo systemctl disable --now <unit>`, `sudo gpasswd -d "$USER" <group>` (details in `specs/services.md`) |
| flatpak | no | Flatpak and the system-wide flathub remote; apps come from the package groups (`*.flatpak` lists: OBS and Kdenlive in media, ProtonUp-Qt in gaming) | `sudo flatpak uninstall --system <app>`, `sudo flatpak remote-delete --system flathub` (details in `specs/flatpak.md`) |
| mime | no | Default apps in `~/.config/mimeapps.list`: Brave for web, HTML and PDF, PeaZip for zip, Vesktop for discord links; each only if the app is installed | Restore `~/.config/mimeapps.list.bak.<timestamp>` (details in `specs/mime.md`) |
| cosmic-settings | no | COSMIC settings as individual cosmic-config key files: PerWorkspace autotile, keyboard config generated from the system layout (key repeat 600 ms / 25 per s kept; untouched with a warning when there is no X11 layout), Compact density, Papirus-Dark, purple accent with frosted theme, idle disabled, screenshot to clipboard, Super+Shift+S and Alt+S shortcuts, PeaZip actions in Files; no font keys, no panel keys | Restore the `<key>.bak.<timestamp>` files or delete the shipped key files under `~/.config/cosmic/` (details in `specs/cosmic-settings.md`) |
| dark-mode | no | Dark mode outside COSMIC: `adw-gtk3-dark` + `prefer-dark` GSettings for GTK3/4, `qt5ct`/`qt6ct` (Fusion, darker, `QT_QPA_PLATFORMTHEME=qt5ct` in `/etc/environment`), system Flatpak `GTK_THEME` override with the adw-gtk3-dark runtime, `--force-dark-mode` for Electron, Brave and VS Code; no fonts | `gsettings reset` both keys, remove the env line, restore the qt conf backups, `sudo flatpak override --system --unset-env=GTK_THEME`, remove the flag lines (details in `specs/dark-mode.md`) |
| clipboard | no | Clipboard survives closing the source app: `COSMIC_DATA_CONTROL_ENABLED=1` in `/etc/environment` and a `wl-clip-persist` systemd user service | `systemctl --user disable --now wl-clip-persist.service`, remove the unit, delete the line from `/etc/environment`, re-login (details in `specs/clipboard.md`) |
| kitty | no | kitty as default terminal, frosted config, Ctrl+Shift+K clear, `clear` alias that wipes scrollback, selection color from the COSMIC accent (systemd path unit) | Restore the `*.bak.<timestamp>` files, `systemctl --user disable --now kitty-cosmic-colors.path`, remove the `kitty-clear` block from `~/.bashrc` (details in `specs/kitty.md`) |
| fastfetch | no | Installs fastfetch, imagemagick, git-lfs; builds a pool of random logo images in `~/.config/fastfetch/images` from six third-party repos (skip with `FASTFETCH_SKIP_IMAGES=1`); `fastfetch` `~/.bashrc` block shows a random image as logo in kitty only; migrates the legacy unmanaged snippet | Remove the `fastfetch` block from `~/.bashrc`, optionally delete `~/.config/fastfetch/images`, `sudo pacman -Rns fastfetch` (details in `specs/fastfetch.md`) |
| applets | no | COSMIC applets: Workspace Icons, Now Playing (AUR), Lock Keys (built from source); `APPLETS_REBUILD=1` forces update and rebuild; skips builds when installed | Remove the applets from the panel first, then delete the binaries, desktop entries and icons, `yay -Rns cosmic-ext-applet-now-playing-extended-git`, `rm -r ~/.cache/eos-cosmic-setup/src` (details in `specs/applets.md`) |
| panel | no | Single top panel (dock off) with Workspace Icons at the start, Now Playing in the center, and Date/Time, Lock Keys, Notifications Tray, Tiling, Sound, Bluetooth, Network, Power & Battery, Notifications Center, User Session at the end | Restore the `<key>.bak.<timestamp>` files or delete the shipped panel key files under `~/.config/cosmic/` (details in `specs/panel.md`) |
| aura | no | Aura live wallpaper: installs the pinned release (`AURA_VERSION`, default `v1.5.0`, sha256 verified, skipped when `~/.local/bin/aura` exists; `AURA_REINSTALL=1` forces it) and an `aura-restore` systemd user unit that restores the last wallpaper at login with a fallback; removes the old autostart entry and script and keeps Aura's own autostart off; never touches the wallpaper files | `systemctl --user disable --now aura-restore.service`, remove the unit and `~/.local/bin/aura-restore`, restore the autostart `.desktop` and script from their `.bak.<timestamp>` files (details in `specs/aura.md`) |
| steam-icons | no | Workspace Icons shows Steam game icons: `steam-icons-sync` writes `steam_app_<appid>.desktop` (marked `X-Eos-Cosmic-Setup=steam-icons`) and a 32x32 icon per installed game (tools like Proton skipped), kept current by a systemd path unit plus a login run; `steam-icons-learn` (needs `lswt`, AUR) learns the real app_id of native games at runtime into an override file; removes only marked entries of uninstalled games | Disable `steam-icons-sync.path`, `.service` and `steam-icons-learn.service`, remove the units and scripts, delete `steam-wmclass.conf`, delete the marked `steam_app_*.desktop` files and `steam_icon_*.png` (details in `specs/steam-icons.md`) |
| kvm | yes | KVM/QEMU virtualization: qemu-desktop, libvirt, virt-manager, virt-viewer, dnsmasq, UEFI and TPM; enables `libvirtd`, adds you to `libvirt` and `kvm`, starts the default network with autostart; skips if the CPU has no SVM/VT-x | `sudo virsh net-autostart --disable default`, `sudo systemctl disable --now libvirtd`, `sudo gpasswd -d "$USER" libvirt`, remove the packages (details in `specs/kvm.md`) |
| wacom | yes | Maps detected Wacom tablets to the first enabled output in `~/.config/cosmic/com.system76.CosmicComp/v1/input_devices` (cosmic-comp drops tablet events without an internal display); merges, never overwrites; `WACOM_OUTPUT`, `WACOM_FORCE=1` | Restore `input_devices.bak.<timestamp>` (details in `specs/wacom.md`) |
| vesktop-mic | yes | Stops Vesktop from lowering the mic volume: PipeWire `block-source-volume` rule, `--disable-features=WebRtcAllowInputVolumeAdjustment` flag, migrates the old `10-bloquear-agc.conf`; skipped without Vesktop | Delete `~/.config/pipewire/pipewire-pulse.conf.d/10-block-agc.conf` and restart pipewire (details in `specs/vesktop-mic.md`) |

## Not managed

- **Bootloader and kernel parameters.** The EndeavourOS installer configures
  GRUB (or systemd-boot) and the initramfs correctly for each machine. The
  reference host's extra parameters (`nowatchdog`, `nvme_load=YES`,
  `usbcore.initial_descriptor_timeout=1000`) are tied to its hardware, and a
  wrong boot setting can leave a machine unbootable, so there is no boot module.
- **Personal data and secrets:** wallpapers, browser profiles, app state, SSH
  and GPG keys. Wallpapers for Aura go in `~/Pictures/Wallpapers/Aura`.
