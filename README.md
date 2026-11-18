# eos-cosmic-setup

Turns a fresh EndeavourOS + COSMIC install into a configured desktop with one
command. It is a set of small, idempotent bash modules that detect CPU and GPU
vendor at run time, so the same repository works across machines.

## Requirements

- EndeavourOS with the COSMIC desktop
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

See `modules/README.md` for the module contract and `specs/README.md` for the
spec template.

## Modules

All modules are planned; none are implemented yet.

| Module | Opt-in | What it does | How to revert |
|--------|--------|--------------|---------------|
| drivers | no | CPU/GPU vendor detection: microcode, Vulkan, ROCm on AMD (planned) | TBD |
| pacman-conf | no | Pacman configuration (planned) | TBD |
| packages | no | Base package set (planned) | TBD |
| locale | no | Locale settings (planned) | TBD |
| services | no | System and user services (planned) | TBD |
| flatpak | no | Flatpak setup (planned) | TBD |
| mime | no | Default applications and MIME associations (planned) | TBD |
| cosmic-settings | no | COSMIC desktop settings (planned) | TBD |
| dark-mode | no | Dark theme (planned) | TBD |
| clipboard | no | Clipboard survives closing the source app: `COSMIC_DATA_CONTROL_ENABLED=1` in `/etc/environment` and a `wl-clip-persist` systemd user service | `systemctl --user disable --now wl-clip-persist.service`, remove the unit, delete the line from `/etc/environment`, re-login (details in `specs/clipboard.md`) |
| kitty | no | kitty as default terminal, frosted config, Ctrl+Shift+K clear, `clear` alias that wipes scrollback, selection color from the COSMIC accent (systemd path unit) | Restore the `*.bak.<timestamp>` files, `systemctl --user disable --now kitty-cosmic-colors.path`, remove the `kitty-clear` block from `~/.bashrc` (details in `specs/kitty.md`) |
| fastfetch | no | Installs fastfetch, imagemagick, git-lfs; builds a pool of random logo images in `~/.config/fastfetch/images` from seven third-party repos (skip with `FASTFETCH_SKIP_IMAGES=1`); `fastfetch` `~/.bashrc` block shows a random image as logo in kitty only; migrates the legacy unmanaged snippet | Remove the `fastfetch` block from `~/.bashrc`, optionally delete `~/.config/fastfetch/images`, `sudo pacman -Rns fastfetch` (details in `specs/fastfetch.md`) |
| applets | no | COSMIC applets (planned) | TBD |
| panel | no | COSMIC panel layout (planned) | TBD |
| aura | no | Aura configuration (planned) | TBD |
| steam-icons | no | Steam icon fixes (planned) | TBD |
| kvm | yes | Virtualization with KVM/QEMU (planned) | TBD |
| wacom | yes | Wacom tablet support (planned) | TBD |
| vesktop-mic | yes | Vesktop microphone setup (planned) | TBD |
| boot | yes | Bootloader configuration (planned) | TBD |
