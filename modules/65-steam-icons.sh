#!/usr/bin/env bash
# modules/65-steam-icons.sh: desktop entries and icons for Steam games so Workspace Icons shows them.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="steam-icons"
# shellcheck disable=SC2034
MODULE_DESC="Steam game icons: steam-icons-sync script and units, steam-icons-learn service (needs lswt)"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS=""

# _steam_icons_pending <script>: run the shipped script in dry-run mode, turn
# each "would ..." line into a change and set _STEAM_ICONS_PENDING to how many
# there were (a global, because a subshell would lose the CHANGES counter).
_steam_icons_pending() {
  local script="$1" line out n=0
  _STEAM_ICONS_PENDING=0
  if ! out="$(bash "$script" --dry-run)"; then
    log_error "steam-icons: the sync preview failed"
    return 1
  fi
  while IFS= read -r line; do
    if [[ "$line" == "would "* ]]; then
      log_change "steam-icons: ${line#would }"
      n=$((n + 1))
    fi
  done <<<"$out"
  _STEAM_ICONS_PENDING=$n
}

module_apply() {
  local src="$REPO_ROOT/files/steam-icons"
  local unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  local script="$HOME/.local/bin/steam-icons-sync"
  local learn="$HOME/.local/bin/steam-icons-learn"
  local changed=0 learn_changed=0

  ensure_packages imagemagick
  ensure_aur_packages lswt

  cmp -s -- "$src/steam-icons-sync" "$script" || changed=1
  cmp -s -- "$src/steam-icons-sync.service" "$unit_dir/steam-icons-sync.service" || changed=1
  cmp -s -- "$src/steam-icons-sync.path" "$unit_dir/steam-icons-sync.path" || changed=1
  cmp -s -- "$src/steam-icons-learn" "$learn" || learn_changed=1
  cmp -s -- "$src/steam-icons-learn.service" "$unit_dir/steam-icons-learn.service" || learn_changed=1
  ((learn_changed)) && changed=1
  install_file "$src/steam-icons-sync" "$script" 0755
  install_file "$src/steam-icons-sync.service" "$unit_dir/steam-icons-sync.service" 0644
  install_file "$src/steam-icons-sync.path" "$unit_dir/steam-icons-sync.path" 0644
  install_file "$src/steam-icons-learn" "$learn" 0755
  install_file "$src/steam-icons-learn.service" "$unit_dir/steam-icons-learn.service" 0644
  if ((changed)); then
    run systemctl --user daemon-reload
  fi

  # Count the pending work with the shipped script's own logic (read-only), then
  # apply it with the installed script. Doing it before enabling keeps the
  # counts exact: enable --now would run the sync a second time and find nothing.
  _steam_icons_pending "$src/steam-icons-sync" || return 1
  if ((_STEAM_ICONS_PENDING > 0)); then
    run "$script" || return 1
  fi

  # The path unit reacts to Steam changes; the service also syncs once per login.
  ensure_user_unit_enabled steam-icons-sync.path
  ensure_user_unit_enabled steam-icons-sync.service

  # The learn service watches windows for the real app_id of native games. A
  # changed script or unit needs a restart to take effect (enable --now only
  # starts it when it was not running).
  ensure_user_unit_enabled steam-icons-learn.service
  if ((learn_changed)) && systemctl --user is-active --quiet steam-icons-learn.service 2>/dev/null; then
    run systemctl --user try-restart steam-icons-learn.service
  fi
}
