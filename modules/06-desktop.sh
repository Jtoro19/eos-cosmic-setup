#!/usr/bin/env bash
# modules/06-desktop.sh: COSMIC desktop, its greeter and the session base.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="desktop"
# shellcheck disable=SC2034
MODULE_DESC="COSMIC desktop and greeter plus audio, bluetooth and network base (for a no-desktop install)"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS="pacman-conf"

# Members of the cosmic group that the reference host does not use:
# a first-login wizard (would override this repo's settings), the on-screen
# keyboard and the system monitor.
_DESKTOP_SKIP=(cosmic-initial-setup cosmic-osk cosmic-monitor)

# Session base an EndeavourOS desktop install normally brings. A no-desktop
# install may lack these; packagekit is what COSMIC Store installs through.
_DESKTOP_BASE=(
  xorg-xwayland
  pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber
  bluez bluez-utils
  networkmanager
  power-profiles-daemon
  gnome-keyring
  xdg-user-dirs
  packagekit
  cups avahi
  firewalld
)

# Display managers to turn off so cosmic-greeter owns display-manager.service.
# pacman-init is the live ISO's keyring service, which can be left enabled.
_DESKTOP_OTHER_DM=(gdm lightdm sddm lxdm ly pacman-init)

# _desktop_cosmic_packages: the cosmic group from the sync database, minus
# the skipped members. Falls back to the core session packages if the group
# cannot be read.
_desktop_cosmic_packages() {
  local -a group=()
  local p s skip
  mapfile -t group < <(pacman -Sgq cosmic 2>/dev/null)
  if ((${#group[@]} == 0)); then
    group=(cosmic-session cosmic-comp cosmic-greeter cosmic-panel cosmic-settings
      cosmic-settings-daemon cosmic-applets cosmic-files cosmic-terminal
      xdg-desktop-portal-cosmic)
  fi
  for p in "${group[@]}"; do
    skip=0
    for s in "${_DESKTOP_SKIP[@]}"; do
      [[ "$p" == "$s" ]] && skip=1
    done
    ((skip)) || printf '%s\n' "$p"
  done
}

module_apply() {
  local -a cosmic=() missing=()
  local p s
  mapfile -t cosmic < <(_desktop_cosmic_packages)

  # First run on a fresh install: bring the system up to date before adding
  # the desktop, so the new packages match the rest of the system.
  for p in "${cosmic[@]}" "${_DESKTOP_BASE[@]}"; do
    pkg_installed "$p" || missing+=("$p")
  done
  if ((${#missing[@]} > 0)); then
    log_change "full system upgrade before installing the desktop"
    run_sudo pacman -Syu --noconfirm || return 1
  fi
  ensure_packages "${cosmic[@]}" "${_DESKTOP_BASE[@]}" || return 1

  # cosmic-greeter as the display manager: turn off any other one first.
  for s in "${_DESKTOP_OTHER_DM[@]}"; do
    if systemctl is-enabled --quiet "$s.service" >/dev/null 2>&1; then
      log_change "disable $s.service"
      run_sudo systemctl disable "$s.service"
    fi
  done
  if ! systemctl is-enabled --quiet cosmic-greeter.service >/dev/null 2>&1; then
    log_change "enable display manager: cosmic-greeter"
    run_sudo systemctl enable cosmic-greeter.service
    log_warn "reboot to reach the COSMIC login"
  fi

  # Graphical target as the default boot target.
  if [[ "$(systemctl get-default 2>/dev/null)" != "graphical.target" ]]; then
    log_change "set default boot target: graphical.target"
    run_sudo systemctl set-default graphical.target
  fi
}
