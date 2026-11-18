#!/usr/bin/env bash
# modules/30-clipboard.sh: persistent Wayland clipboard on COSMIC.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="clipboard"
# shellcheck disable=SC2034
MODULE_DESC="persistent clipboard: COSMIC data-control env var, wl-clip-persist user service"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS=""

module_apply() {
  local src="$REPO_ROOT/files/clipboard"
  local unit="$HOME/.config/systemd/user/wl-clip-persist.service"
  local legacy_autostart="$HOME/.config/autostart/wl-clip-persist.desktop"
  local changed=0

  ensure_packages wl-clipboard wl-clip-persist

  # COSMIC disables the data-control protocol by default; wl-clip-persist needs it.
  # /etc/environment survives session file updates. Takes effect after re-login.
  ensure_line /etc/environment "COSMIC_DATA_CONTROL_ENABLED=1"

  cmp -s -- "$src/wl-clip-persist.service" "$unit" || changed=1
  install_file "$src/wl-clip-persist.service" "$unit" 0644
  if ((changed)); then
    run systemctl --user daemon-reload
  fi
  ensure_user_unit_enabled wl-clip-persist.service
  if ((changed)); then
    # Pick up the new unit; no-op if the service is not running.
    run systemctl --user try-restart wl-clip-persist.service
  fi

  # COSMIC autostart was unreliable for this; the systemd unit replaces it.
  if [[ -e "$legacy_autostart" ]]; then
    log_change "remove legacy autostart entry $legacy_autostart"
    backup_file "$legacy_autostart"
    run rm -f -- "$legacy_autostart"
  fi
}
