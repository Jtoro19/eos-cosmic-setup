#!/usr/bin/env bash
# modules/75-mime.sh: default applications in ~/.config/mimeapps.list.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="mime"
# shellcheck disable=SC2034
MODULE_DESC="default applications (browser, PDF, zip, discord links) for installed apps only"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS=""

# mime-type=desktop-id pairs. A pair is applied only when the desktop entry is
# installed, so optional groups that were not selected are simply skipped.
_MIME_DEFAULTS=(
  "text/html=brave-browser.desktop"
  "x-scheme-handler/http=brave-browser.desktop"
  "x-scheme-handler/https=brave-browser.desktop"
  "x-scheme-handler/about=brave-browser.desktop"
  "x-scheme-handler/unknown=brave-browser.desktop"
  "application/pdf=brave-browser.desktop"
  "application/zip=peazip-extract.desktop"
  "x-scheme-handler/discord=vesktop.desktop"
)

# _mime_desktop_installed <desktop-id>: true when the entry exists in an XDG
# applications directory (user, system or Flatpak exports).
_mime_desktop_installed() {
  local id="$1" d
  local data="${XDG_DATA_HOME:-$HOME/.local/share}"
  for d in "$data/applications" /usr/local/share/applications /usr/share/applications \
    "$data/flatpak/exports/share/applications" /var/lib/flatpak/exports/share/applications; do
    [[ -f "$d/$id" ]] && return 0
  done
  return 1
}

module_apply() {
  local list="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list" pair app
  for pair in "${_MIME_DEFAULTS[@]}"; do
    app="${pair#*=}"
    if _mime_desktop_installed "$app"; then
      ensure_ini_line "$list" "Default Applications" "$pair" replace
    else
      log_info "skip ${pair%%=*}: $app is not installed"
    fi
  done
}
