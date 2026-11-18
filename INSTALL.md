# Installation guide

Set up a new machine with this repository: from a fresh EndeavourOS install
(with COSMIC, or with no desktop at all) to the full desktop in one run. It
works on any CPU or GPU vendor; hardware is detected at run time.

## Quick path

1. **Install EndeavourOS.** Online install. Pick **COSMIC** as the desktop, or
   **no desktop** (the `desktop` module installs COSMIC). Use any user name.
2. **Clone the repository** (from a terminal or a TTY):

   ```bash
   sudo pacman -Syu --needed git
   git clone https://github.com/Jtoro19/eos-cosmic-setup.git ~/eos-cosmic-setup
   cd ~/eos-cosmic-setup
   ```

3. **Preview** what would change (applies nothing):

   ```bash
   ./install.sh --all --dry-run 2>&1 | tail -40
   ```

4. **Install**, keeping a log:

   ```bash
   ./install.sh --all 2>&1 | tee ~/install.log
   ```

   Add optional groups with `--only`, for example
   `./install.sh --all --only packages-dev,packages-gaming`.
   Expect 20 to 40 minutes on a fresh machine: most of it is compiling two
   applets in Rust and one AUR package.

5. **Run it again** to confirm nothing is left to do:

   ```bash
   ./install.sh --all
   ```

   The last line must read `total changes: 0`.

6. **Reboot.** The machine boots to the COSMIC login.

## Optional modules

Opt-in modules run only when named with `--only`. Combine them freely:
`./install.sh --all --only packages-dev,packages-media,kvm`.

| Module | Use it when |
|--------|-------------|
| `packages-dev` | You develop: Docker, MariaDB, Go, Rust, Python, VS Code, Claude Code |
| `packages-gaming` | You play: Steam, GameMode, MangoHud, ProtonUp-Qt |
| `packages-media` | Creative and media apps: GIMP, Krita, Spotify, Vesktop, OBS, Kdenlive |
| `packages-office` | LibreOffice and Obsidian |
| `packages-printing` | You print or scan: CUPS drivers, HPLIP, SANE |
| `packages-ai` | Local AI: Ollama built for your GPU (ROCm, CUDA or CPU) |
| `packages-vmware` | VMware Workstation |
| `kvm` | Virtual machines with QEMU/libvirt and virt-manager |
| `wacom` | A Wacom tablet on a machine without an internal display |
| `vesktop-mic` | Vesktop keeps lowering your microphone volume |

`./install.sh --list` shows every module and whether it is opt-in.

**Install everything**, defaults plus every optional module (it reads the
opt-in list from `--list`, so new modules are included automatically):

```bash
./install.sh --all --only "$(./install.sh --list | awk '$2=="yes"{print $1}' | paste -sd,)" 2>&1 | tee ~/install.log
```

That is the same as naming them all:

```bash
./install.sh --all --only packages-dev,packages-gaming,packages-media,packages-office,packages-printing,packages-ai,packages-vmware,kvm,wacom,vesktop-mic
```

Hardware modules stay safe on any machine: `kvm` skips if the CPU has no
virtualization, `wacom` does nothing without a tablet, and `vesktop-mic` does
nothing without Vesktop. Expect a longer first run (Steam, LibreOffice,
VMware and the Ollama build for your GPU are large downloads).

**Adding a group later** works the same on a machine that is already set up:
modules that are done are skipped and only the new group is installed. For
example, to add Steam and OBS afterwards:

```bash
cd ~/eos-cosmic-setup && ./install.sh --all --only packages-gaming,packages-media
```

## Settings by environment variable

Set them in front of the command, for example
`LOCALE_TZ=America/Bogota ./install.sh --all`.

| Variable | Effect |
|----------|--------|
| `LOCALE_TZ=<zone>` | Set the time zone (otherwise the installer's choice is kept) |
| `SERVICES_SSHD=1` | Also enable the SSH server |
| `FASTFETCH_SKIP_IMAGES=1` | Skip downloading the fastfetch logo images |
| `APPLETS_REBUILD=1` | Update and rebuild Workspace Icons and Lock Keys |
| `AURA_VERSION=<tag>` | Aura release to install (default `v1.5.0`) |
| `AURA_REINSTALL=1` | Reinstall Aura, for example to change version |
| `WACOM_OUTPUT=<name>` | Map the tablet to this output instead of the first one |
| `WACOM_FORCE=1` | Map the tablet even if an internal display exists |

## After installing

- **NVIDIA GPU:** run `nvidia-inst` once, then reboot. It picks the right
  driver and asks a few questions, so the installer does not run it for you.
  GTX 10xx and older may need the legacy `nvidia-580xx-dkms` driver (AUR).
- **Aura wallpapers:** copy your videos to `~/Pictures/Wallpapers/Aura`, apply
  one in Aura, and it comes back at every login.
- **Steam game icons:** nothing to do. When a game finishes installing, its
  launcher and icon are created automatically (and again at every login).
  Proton games show their icon from the first launch. A native game shows a
  generic icon the first time; reopen it once and its icon appears from then
  on. To check that a game was picked up:

  ```bash
  eza ~/.local/share/applications | rg steam_app
  ```
- **Groups** (docker, libvirt, kvm): log out and back in to use them.

## Checklist after the first login

- [ ] The panel has Workspace Icons on the left, Now Playing in the center, and
      the clock, Lock Keys and system applets on the right.
- [ ] The theme is dark with the purple accent and frosted glass.
- [ ] `Super+T` opens kitty, with fastfetch and a random image.
- [ ] `Super+Shift+S` opens the screenshot tool; `Alt+S` opens the Aura switcher.
- [ ] GTK, Qt and Flatpak apps open in dark mode.
- [ ] Copied text survives closing the app it came from.

## If something goes wrong

| Symptom | What to do |
|---------|------------|
| A module failed | Read the `[error]` line in `~/install.log`, fix the cause, run `./install.sh --all` again. Finished modules are skipped. |
| You want to undo a change | Every overwritten file has a `<file>.bak.<timestamp>` copy next to it. The README lists how to revert each module. |
| `yay is required` | AUR modules need `yay`, which EndeavourOS ships. Install it, then run again. |
| An image repository is gone | fastfetch logs a warning and continues; nothing to do. |
| A Steam game keeps a generic icon | Close and reopen the game. If it persists, run `~/.local/bin/steam-icons-sync`, check `journalctl --user -u steam-icons-learn`, or set its app id by hand in `~/.config/eos-cosmic-setup/steam-wmclass.conf` (`<appid>=<app_id>`; read the app id with `lswt` while the game runs). |
| No COSMIC login after reboot | Check `systemctl status cosmic-greeter` and run `./install.sh --only desktop`. |

## Updating

Pull and run again; only what changed is applied:

```bash
cd ~/eos-cosmic-setup && git pull && ./install.sh --all
```

See `README.md` for what each module does and how to revert it.
