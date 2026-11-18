#!/usr/bin/env bash
# modules/50-applets.sh: COSMIC panel applets (Workspace Icons, Now Playing, Lock Keys).

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="applets"
# shellcheck disable=SC2034
MODULE_DESC="COSMIC applets: Workspace Icons, Now Playing (AUR), Lock Keys (built from source)"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS=""

_APPLETS_WI_NAME="cosmic-ext-applet-workspace-icons"
_APPLETS_WI_ID="io.github.crocodile.cosmic-ext-applet-workspace-icons"
_APPLETS_WI_URL="https://github.com/crocodile/cosmic-ext-applet-workspace-icons"
_APPLETS_LK_NAME="cosmic-ext-lock-keys"
_APPLETS_LK_URL="https://github.com/lucianosb/cosmic-applet-lock-keys"

# _applets_src_dir <repo-name>: source checkout location (kept for updates).
_applets_src_dir() {
  printf '%s/eos-cosmic-setup/src/%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}" "$1"
}

# _applets_checkout <url> <dir>: shallow clone when missing; pull only when
# APPLETS_REBUILD=1 and the checkout already exists.
_applets_checkout() {
  local url="$1" dir="$2"
  if [[ ! -d "$dir/.git" ]]; then
    run mkdir -p -- "$(dirname "$dir")"
    GIT_TERMINAL_PROMPT=0 run git clone --depth 1 -- "$url" "$dir"
  elif [[ "${APPLETS_REBUILD:-0}" == "1" ]]; then
    # An update that cannot be fetched (offline) is not fatal: build what is
    # already checked out.
    GIT_TERMINAL_PROMPT=0 run_may_fail git -C "$dir" pull --ff-only ||
      log_warn "could not update $dir; building the existing checkout"
  fi
}

# _applets_cargo_build <dir>: release build with the target dir inside the checkout.
_applets_cargo_build() {
  local dir="$1"
  run env CARGO_TARGET_DIR="$dir/target" cargo build --release --manifest-path "$dir/Cargo.toml" </dev/null
}

# _applets_build_deps: toolchain needed to compile the two applets.
_applets_build_deps() {
  # An existing cargo (for example from rustup) is kept; do not add the rust package.
  if ! command -v cargo >/dev/null 2>&1; then
    ensure_packages rust
  fi
  ensure_packages git base-devel
}

# _applets_workspace_icons: user-local install, same layout as upstream `just install`.
_applets_workspace_icons() {
  local src="$REPO_ROOT/files/applets"
  local bin="$HOME/.local/bin/$_APPLETS_WI_NAME"
  local share="${XDG_DATA_HOME:-$HOME/.local/share}"
  local dir res f rel

  # Desktop entry (Exec= holds the home path) and config keys: cheap, always managed.
  install_template "$src/$_APPLETS_WI_ID.desktop.in" \
    "$share/applications/$_APPLETS_WI_ID.desktop" 0644
  while IFS= read -r -d '' f; do
    rel="${f#"$src"/cosmic/}"
    install_file "$f" "$HOME/.config/cosmic/$rel" 0644
  done < <(find "$src/cosmic" -type f -print0 | sort -z)

  if [[ -x "$bin" && "${APPLETS_REBUILD:-0}" != "1" ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] would build %s from %s\n' "$_APPLETS_WI_NAME" "$_APPLETS_WI_URL"
    log_change "build and install $_APPLETS_WI_NAME"
    return 0
  fi

  log_change "build and install $_APPLETS_WI_NAME from $_APPLETS_WI_URL"
  dir="$(_applets_src_dir "$_APPLETS_WI_NAME")"
  res="$dir/resources"
  _applets_build_deps
  _applets_checkout "$_APPLETS_WI_URL" "$dir"
  _applets_cargo_build "$dir"
  run install -Dm0755 "$dir/target/release/$_APPLETS_WI_NAME" "$bin"
  run install -Dm0644 "$res/$_APPLETS_WI_ID.svg" \
    "$share/icons/hicolor/scalable/apps/$_APPLETS_WI_ID.svg"
  run install -Dm0644 "$res/$_APPLETS_WI_ID.metainfo.xml" \
    "$share/metainfo/$_APPLETS_WI_ID.metainfo.xml"
  # Refresh the user icon cache only when one already exists.
  if [[ -f "$share/icons/hicolor/icon-theme.cache" ]] && command -v gtk-update-icon-cache >/dev/null 2>&1; then
    run gtk-update-icon-cache -f -t "$share/icons/hicolor"
  fi
}

# _applets_lock_keys: manual install into /usr (the upstream justfile is broken).
_applets_lock_keys() {
  local bin="/usr/bin/$_APPLETS_LK_NAME" dir

  if [[ -e "$bin" && "${APPLETS_REBUILD:-0}" != "1" ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] would build %s from %s\n' "$_APPLETS_LK_NAME" "$_APPLETS_LK_URL"
    log_change "build and install $_APPLETS_LK_NAME"
    return 0
  fi

  log_change "build and install $_APPLETS_LK_NAME from $_APPLETS_LK_URL"
  dir="$(_applets_src_dir cosmic-applet-lock-keys)"
  _applets_build_deps
  _applets_checkout "$_APPLETS_LK_URL" "$dir"
  _applets_cargo_build "$dir"
  run_sudo install -Dm0755 "$dir/target/release/$_APPLETS_LK_NAME" "$bin"
  run_sudo install -Dm0644 -t /usr/share/applications/ "$dir"/data/*.desktop
  run_sudo install -Dm0644 -t /usr/share/icons/hicolor/scalable/apps/ "$dir"/data/icons/*.svg
  run_sudo gtk-update-icon-cache -f /usr/share/icons/hicolor
}

module_apply() {
  _applets_workspace_icons
  ensure_aur_packages cosmic-ext-applet-now-playing-extended-git
  _applets_lock_keys
}
