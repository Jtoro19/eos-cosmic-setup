#!/usr/bin/env bash
# modules/55-panel.sh: COSMIC top panel layout and applet order.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="panel"
# shellcheck disable=SC2034
MODULE_DESC="COSMIC panel: single top panel with the applet order from panel-applets.png"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS="applets"

module_apply() {
  local src="$REPO_ROOT/files/panel"
  local dest="$HOME/.config/cosmic"
  local rel

  # cosmic-config stores one file per key; cosmic-panel reloads them live.
  while IFS= read -r rel; do
    install_file "$src/$rel" "$dest/$rel" 0644
  done < <(cd "$src" && find . -type f ! -name '*.bak.*' -printf '%P\n' | sort)
}
