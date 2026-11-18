#!/usr/bin/env bash
# modules/20-cosmic-settings.sh: COSMIC desktop settings (cosmic-config key files).

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="cosmic-settings"
# shellcheck disable=SC2034
MODULE_DESC="COSMIC settings: tiling, keyboard, theme, icons, shortcuts, idle, files, terminal"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS=""

module_apply() {
  local src="$REPO_ROOT/files/cosmic"
  local dst="$HOME/.config/cosmic"
  local f rel dest
  # Keys the desktop rewrites by itself (window state): seed them only when
  # missing so a later run never fights the user.
  local -a seed_only=("com.system76.CosmicPortal/v1/screenshot")
  local -a files=()

  # Papirus-Dark (CosmicTk icon_theme) needs this package.
  ensure_packages papirus-icon-theme

  # cosmic-config stores one file per key. Install each shipped key on its own
  # and never touch keys that are not shipped. cosmic-config watches the files,
  # so no restart is needed.
  while IFS= read -r -d '' f; do
    files+=("${f#"$src"/}")
  done < <(find "$src" -type f -print0 | sort -z)

  for rel in "${files[@]}"; do
    case "$rel" in
      *.in)
        install_template "$src/$rel" "$dst/${rel%.in}" 0644
        ;;
      *)
        dest="$dst/$rel"
        if [[ " ${seed_only[*]} " == *" $rel "* && -e "$dest" ]]; then
          continue
        fi
        install_file "$src/$rel" "$dest" 0644
        ;;
    esac
  done
}
