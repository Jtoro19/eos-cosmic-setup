#!/usr/bin/env bash
# modules/40-kitty.sh: kitty terminal config, COSMIC accent sync, default terminal.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="kitty"
# shellcheck disable=SC2034
MODULE_DESC="kitty terminal: config, COSMIC accent colors, clear alias, default terminal"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS=""

module_apply() {
  local src="$REPO_ROOT/files/kitty"
  local unit_dir="$HOME/.config/systemd/user"
  local bin="$HOME/.local/bin/kitty-cosmic-colors.sh"
  local cosmic_cfg="$HOME/.config/cosmic"
  local actions="$cosmic_cfg/com.system76.CosmicSettings.Shortcuts/v1/system_actions"
  local before after f
  local alias_line legacy_comment

  ensure_packages kitty

  # Snapshot checksums of script and units to detect changes.
  _kitty_sum() {
    local p
    for p in "$bin" "$unit_dir/kitty-cosmic-colors.service" "$unit_dir/kitty-cosmic-colors.path"; do
      cksum <"$p" 2>/dev/null || printf 'none\n'
    done
  }
  before="$(_kitty_sum)"

  install_file "$src/kitty.conf" "$HOME/.config/kitty/kitty.conf" 0644
  install_file "$src/kitty-cosmic-colors.sh" "$bin" 0755
  install_file "$src/kitty-cosmic-colors.service" "$unit_dir/kitty-cosmic-colors.service" 0644
  install_file "$src/kitty-cosmic-colors.path" "$unit_dir/kitty-cosmic-colors.path" 0644

  # In dry-run nothing is written, so compare file content to the payload.
  after="$(_kitty_sum)"
  f=0
  if [[ "$DRY_RUN" == "1" ]]; then
    cmp -s -- "$src/kitty-cosmic-colors.sh" "$bin" || f=1
    cmp -s -- "$src/kitty-cosmic-colors.service" "$unit_dir/kitty-cosmic-colors.service" || f=1
    cmp -s -- "$src/kitty-cosmic-colors.path" "$unit_dir/kitty-cosmic-colors.path" || f=1
  elif [[ "$before" != "$after" ]]; then
    f=1
  fi

  if ((f)); then
    run systemctl --user daemon-reload
  fi
  ensure_user_unit_enabled kitty-cosmic-colors.path
  if ((f)); then
    # Regenerate the (not shipped) cosmic-colors.conf.
    run "$bin"
  fi

  # Bash clear alias that also clears scrollback.
  alias_line='alias clear='\''printf "\e[H\e[2J\e[3J"'\'''
  # Legacy Spanish comment that older setups left above the alias (match only).
  legacy_comment='# clear que también borra el historial de scroll'
  remove_line "$HOME/.bashrc" "$alias_line" "$legacy_comment"
  ensure_block "$HOME/.bashrc" kitty-clear "$alias_line"

  # Default terminal for COSMIC.
  if [[ ! -e "$actions" ]]; then
    install_file "$src/system_actions" "$actions" 0644
  elif ! grep -q 'Terminal: *"kitty"' "$actions"; then
    log_warn "$actions exists without Terminal: \"kitty\"; not merging RON, edit it by hand"
  fi
  ensure_ini_line "$HOME/.config/cosmic-mimeapps.list" "Default Applications" \
    "x-scheme-handler/terminal=kitty.desktop"
  ensure_ini_line "$HOME/.config/cosmic-mimeapps.list" "Default Applications" \
    "application/x-terminal-emulator=kitty.desktop"
}
