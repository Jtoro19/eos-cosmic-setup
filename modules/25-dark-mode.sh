#!/usr/bin/env bash
# modules/25-dark-mode.sh: dark mode for GTK, Qt, Flatpak and Electron/Chromium apps.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="dark-mode"
# shellcheck disable=SC2034
MODULE_DESC="dark mode for GTK3/4, Qt5/6 (qt5ct/qt6ct), Flatpak and Electron/Chromium apps"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS="cosmic-settings"

# _dark_mode_gtk: GTK3, GTK4 and libadwaita via adw-gtk-theme and GSettings.
_dark_mode_gtk() {
  ensure_packages adw-gtk-theme
  ensure_gsetting org.gnome.desktop.interface gtk-theme "'adw-gtk3-dark'"
  ensure_gsetting org.gnome.desktop.interface color-scheme "'prefer-dark'"
}

# _dark_mode_qt: Qt5 and Qt6 through qt5ct/qt6ct.
_dark_mode_qt() {
  local src="$REPO_ROOT/files/dark-mode"
  local env_file=/etc/environment

  ensure_packages qt5ct qt6ct

  # The qt6ct plugin registers both the qt6ct and qt5ct keys, so with one
  # value Qt6 apps load qt6ct and Qt5 apps load qt5ct. Takes effect after
  # re-login. Never add a second QT_QPA_PLATFORMTHEME line.
  if [[ -f "$env_file" ]] && grep -q '^QT_QPA_PLATFORMTHEME=' "$env_file" &&
    ! grep -qxF 'QT_QPA_PLATFORMTHEME=qt5ct' "$env_file"; then
    log_warn "$env_file sets QT_QPA_PLATFORMTHEME to another value; not adding a second line"
  else
    ensure_line "$env_file" "QT_QPA_PLATFORMTHEME=qt5ct"
  fi

  # Manage only the [Appearance] keys: qt5ct/qt6ct store their own state
  # (window geometry, etc.) in the same file when their GUI is opened.
  local tool line
  for tool in qt5ct qt6ct; do
    while IFS= read -r line; do
      [[ -z "$line" || "$line" == \[* ]] && continue
      ensure_ini_line "$HOME/.config/$tool/$tool.conf" Appearance "$line" replace
    done <"$src/$tool.conf"
  done
}

# _dark_mode_flatpak: system-wide adw-gtk3-dark runtime and GTK_THEME override.
_dark_mode_flatpak() {
  local theme=org.gtk.Gtk3theme.adw-gtk3-dark

  if ! command -v flatpak >/dev/null 2>&1; then
    log_info "flatpak not installed; skipping Flatpak dark mode"
    return 0
  fi

  ensure_flatpaks "$theme" || return 1

  if ! flatpak override --system --show 2>/dev/null |
    awk '/^\[/ { env = ($0 == "[Environment]") } env && $0 == "GTK_THEME=adw-gtk3-dark" { found = 1 } END { exit !found }'; then
    log_change "set system Flatpak override GTK_THEME=adw-gtk3-dark"
    run_sudo flatpak override --system --env=GTK_THEME=adw-gtk3-dark
  fi
}

# _dark_mode_electron: dark UI for Electron and Chromium based apps.
_dark_mode_electron() {
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}" f
  # Dark app UI only; WebContentsForceDark would recolor websites.
  for f in electron-flags.conf brave-flags.conf code-flags.conf; do
    ensure_line "$cfg/$f" "--force-dark-mode"
  done
}

module_apply() {
  _dark_mode_gtk
  _dark_mode_qt
  _dark_mode_flatpak
  _dark_mode_electron
}
