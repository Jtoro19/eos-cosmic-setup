#!/usr/bin/env bash
# modules/60-aura.sh: Aura live wallpaper (pinned release) and last-wallpaper restore at login.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="aura"
# shellcheck disable=SC2034
MODULE_DESC="Aura live wallpaper: pinned release install, restore-last-wallpaper user unit"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS=""

_AURA_REPO_URL="https://github.com/antwny/aura/releases/download"

# _aura_download_install <tmp-dir>: download, verify and install the release.
_aura_download_install() {
  local tmp="$1" ver="${AURA_VERSION:-v1.5.0}"
  local name="aura-${ver}-x86_64-linux" tarball url expected actual pkg
  local bin_dir="$HOME/.local/bin"
  local share="${XDG_DATA_HOME:-$HOME/.local/share}"
  local desktop line before="$CHANGES"
  tarball="$tmp/$name.tar.gz"
  url="$_AURA_REPO_URL/$ver/$name.tar.gz"

  if [[ "$(uname -m)" != "x86_64" ]]; then
    log_error "aura: the release is x86_64 only (this machine is $(uname -m))"
    return 1
  fi

  log_info "aura: downloading $url"
  if ! curl -fsSL --retry 2 --connect-timeout 15 -o "$tarball" "$url"; then
    log_error "aura: download failed: $url"
    return 1
  fi
  if ! curl -fsSL --retry 2 --connect-timeout 15 -o "$tarball.sha256" "$url.sha256"; then
    log_error "aura: checksum file unavailable, refusing to install unverified binaries"
    return 1
  fi
  expected="$(awk 'NR == 1 { print $1 }' "$tarball.sha256")"
  actual="$(sha256sum -- "$tarball" | awk '{ print $1 }')"
  if [[ ! "$expected" =~ ^[0-9a-fA-F]{64}$ || "${expected,,}" != "$actual" ]]; then
    log_error "aura: sha256 mismatch for $name.tar.gz (expected '$expected', got '$actual')"
    return 1
  fi
  log_ok "aura: sha256 verified"

  if ! tar -xzf "$tarball" -C "$tmp"; then
    log_error "aura: cannot extract $name.tar.gz"
    return 1
  fi
  pkg="$tmp/$name"
  if [[ ! -f "$pkg/aura" ]]; then
    log_error "aura: unexpected tarball layout, $name/aura not found"
    return 1
  fi

  # Same files and paths as the upstream installer (--user mode).
  install_file "$pkg/aura" "$bin_dir/aura" 0755 || return 1
  if [[ -f "$pkg/mpvpaper" ]]; then
    install_file "$pkg/mpvpaper" "$bin_dir/mpvpaper" 0755 || return 1
  fi
  install_file "$pkg/io.github.antwny.aura.svg" \
    "$share/icons/hicolor/scalable/apps/io.github.antwny.aura.svg" 0644 || return 1
  install_file "$pkg/io.github.antwny.aura.metainfo.xml" \
    "$share/metainfo/io.github.antwny.aura.metainfo.xml" 0644 || return 1

  # Desktop entry: absolute Exec and a TryExec just above it, like upstream.
  desktop="$tmp/io.github.antwny.aura.desktop"
  : >"$desktop"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == Exec=* ]]; then
      printf 'TryExec=%s/aura\nExec=%s/aura\n' "$bin_dir" "$bin_dir" >>"$desktop"
    elif [[ "$line" != TryExec=* ]]; then
      printf '%s\n' "$line" >>"$desktop"
    fi
  done <"$pkg/io.github.antwny.aura.desktop"
  install_file "$desktop" "$share/applications/io.github.antwny.aura.desktop" 0644 || return 1

  # Refresh caches only when something was installed.
  if ((CHANGES != before)); then
    if command -v update-desktop-database >/dev/null 2>&1; then
      run_may_fail update-desktop-database "$share/applications" || true
    fi
    if [[ -f "$share/icons/hicolor/icon-theme.cache" ]] && command -v gtk-update-icon-cache >/dev/null 2>&1; then
      run_may_fail gtk-update-icon-cache -f -t "$share/icons/hicolor" || true
    fi
  fi
}

# _aura_install: pinned release install, skipped when aura is already installed.
_aura_install() {
  local ver="${AURA_VERSION:-v1.5.0}" tmp rc=0

  if [[ -x "$HOME/.local/bin/aura" && "${AURA_REINSTALL:-0}" != "1" ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] would download Aura %s\n' "$ver"
    log_change "download and install Aura $ver"
    return 0
  fi

  log_change "download and install Aura $ver"
  tmp="$(mktemp -d)" || return 1
  _aura_download_install "$tmp" || rc=$?
  rm -rf -- "$tmp"
  return "$rc"
}

# _aura_remove_autostart <path>: back up and remove an autostart entry.
_aura_remove_autostart() {
  log_change "remove autostart entry $1"
  backup_file "$1"
  run rm -f -- "$1"
}

# _aura_legacy_cleanup: one start mechanism only (the systemd unit).
_aura_legacy_cleanup() {
  local autostart="$HOME/.config/autostart"
  local old_script="$HOME/.local/bin/aura-autostart.sh"
  local f

  # Hand-made entry that ran the old start script.
  if [[ -e "$autostart/aura.desktop" ]]; then
    _aura_remove_autostart "$autostart/aura.desktop"
  fi
  if [[ -e "$old_script" ]]; then
    log_change "remove legacy script $old_script"
    backup_file "$old_script"
    run rm -f -- "$old_script"
  fi

  # Any other autostart entry that starts Aura (for example Aura's own).
  if [[ -d "$autostart" ]]; then
    while IFS= read -r -d '' f; do
      [[ "$f" == "$autostart/aura.desktop" ]] && continue
      if grep -qE '^Exec=.*aura' "$f"; then
        _aura_remove_autostart "$f"
      fi
    done < <(find "$autostart" -maxdepth 1 -name '*.desktop' -print0 | sort -z)
  fi
}

# _aura_guard_autostart: keep Aura's own autostart off (the unit restores).
_aura_guard_autostart() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/aura/config.json"
  local tmp mode

  if [[ ! -f "$config" ]]; then
    log_info "aura: no $config yet; apply a wallpaper once with Aura to create it"
    return 0
  fi
  if ! jq -e . "$config" >/dev/null 2>&1; then
    log_warn "aura: $config is not valid JSON; leaving it alone"
    return 0
  fi
  if jq -e '.autostart == false' "$config" >/dev/null 2>&1; then
    return 0
  fi

  tmp="$(mktemp)"
  if ! jq '.autostart = false' "$config" >"$tmp"; then
    rm -f -- "$tmp"
    log_error "aura: cannot update $config"
    return 1
  fi
  mode="$(stat -c %a -- "$config")"
  log_info "aura: setting autostart to false (the aura-restore unit restores the wallpaper)"
  install_file "$tmp" "$config" "$mode"
  rm -f -- "$tmp"
}

module_apply() {
  local src="$REPO_ROOT/files/aura"
  local unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  local unit="$unit_dir/aura-restore.service"
  local script="$HOME/.local/bin/aura-restore"
  local changed=0

  ensure_packages mpv ffmpeg jq curl

  _aura_install || return 1

  # Restore script and its user unit.
  cmp -s -- "$src/aura-restore" "$script" || changed=1
  cmp -s -- "$src/aura-restore.service" "$unit" || changed=1
  install_file "$src/aura-restore" "$script" 0755
  install_file "$src/aura-restore.service" "$unit" 0644
  if ((changed)); then
    run systemctl --user daemon-reload
  fi
  # Enabling starts the unit; it exits at once when a wallpaper is already running.
  ensure_user_unit_enabled aura-restore.service

  _aura_legacy_cleanup
  _aura_guard_autostart
}
