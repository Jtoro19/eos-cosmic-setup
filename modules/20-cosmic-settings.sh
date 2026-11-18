#!/usr/bin/env bash
# modules/20-cosmic-settings.sh: COSMIC desktop settings (cosmic-config key files).

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="cosmic-settings"
# shellcheck disable=SC2034
MODULE_DESC="COSMIC settings: tiling, keyboard (system layout kept), theme, icons, shortcuts, idle, files, terminal"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS=""

# Key repeat of the reference host; the layout itself comes from the system.
_COSMIC_XKB_REPEAT_DELAY=600
_COSMIC_XKB_REPEAT_RATE=25

# _cosmic_ron_escape <text>: escape a value for a RON string literal.
_cosmic_ron_escape() {
  local v="$1"
  v="${v//\\/\\\\}"
  v="${v//\"/\\\"}"
  printf '%s' "$v"
}

# _cosmic_xkb_render <layout> <variant> <options>: print the CosmicComp
# xkb_config RON, byte-exact with what COSMIC writes (no trailing newline).
# An empty variant stays "", empty options become None.
_cosmic_xkb_render() {
  local layout variant opts
  layout="$(_cosmic_ron_escape "$1")"
  variant="$(_cosmic_ron_escape "$2")"
  if [[ -n "$3" ]]; then
    opts="Some(\"$(_cosmic_ron_escape "$3")\")"
  else
    opts="None"
  fi
  printf '(\n    rules: "",\n    model: "",\n    layout: "%s",\n    variant: "%s",\n    options: %s,\n    repeat_delay: %s,\n    repeat_rate: %s,\n)' \
    "$layout" "$variant" "$opts" "$_COSMIC_XKB_REPEAT_DELAY" "$_COSMIC_XKB_REPEAT_RATE"
}

# _cosmic_xkb_field <field>: value of a `localectl status` line such as
# "X11 Layout"; empty when the field is absent, unset or localectl is missing.
_cosmic_xkb_field() {
  localectl status 2>/dev/null | awk -v f="$1:" '
    { line = $0; sub(/^[ \t]+/, "", line) }
    index(line, f) == 1 {
      v = substr(line, length(f) + 1)
      sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
      if (v != "n/a" && v != "(unset)") print v
      exit
    }' || true
}

# _cosmic_xkb_apply <dest>: write the COSMIC keyboard config from the layout
# the system already has (set by the EndeavourOS installer). Leaves the file
# alone, with a warning, when the system reports no X11 layout.
_cosmic_xkb_apply() {
  local dest="$1" layout variant opts tmp
  layout="$(_cosmic_xkb_field "X11 Layout")"
  variant="$(_cosmic_xkb_field "X11 Variant")"
  opts="$(_cosmic_xkb_field "X11 Options")"
  if [[ -z "$layout" ]]; then
    log_warn "localectl reports no X11 keyboard layout; leaving COSMIC xkb_config untouched"
    return 0
  fi
  tmp="$(mktemp)"
  _cosmic_xkb_render "$layout" "$variant" "$opts" >"$tmp"
  install_file "$tmp" "$dest" 0644
  rm -f -- "$tmp"
  _cosmic_greeter_xkb_apply "$layout" "$variant" "$opts"
}

# _cosmic_greeter_xkb_apply <layout> <variant> <options>: give the login screen
# the same keyboard. cosmic-greeter runs its own cosmic-comp as the
# cosmic-greeter system user, which reads xkb_config from that user's home and
# otherwise starts with the default (us) layout, even though the greeter shows
# the user's layout. Its home is not readable without sudo, so the comparison
# falls back to `sudo -n`; a dry-run without sudo skips the step instead of
# reporting a change it cannot verify. EOS_GREETER_USER and EOS_GREETER_HOME
# are test-only overrides.
_cosmic_greeter_xkb_apply() {
  local layout="$1" variant="$2" opts="$3"
  local user="${EOS_GREETER_USER:-cosmic-greeter}" home group dest base tmp d same=0
  home="${EOS_GREETER_HOME:-}"
  if [[ -z "$home" ]]; then
    home="$(getent passwd "$user" 2>/dev/null | cut -d: -f6)"
  fi
  if [[ -z "$home" ]]; then
    log_info "no $user user; login screen keyboard not configured"
    return 0
  fi
  group="$(id -gn "$user" 2>/dev/null || printf '%s' "$user")"
  base="$home/.config/cosmic/com.system76.CosmicComp/v1"
  dest="$base/xkb_config"

  tmp="$(mktemp)"
  _cosmic_xkb_render "$layout" "$variant" "$opts" >"$tmp"
  if [[ -r "$dest" ]]; then
    cmp -s -- "$tmp" "$dest" && same=1
  elif sudo -n true 2>/dev/null; then
    sudo -n cmp -s -- "$tmp" "$dest" 2>/dev/null && same=1
  else
    rm -f -- "$tmp"
    log_info "cannot read the login screen keyboard config without sudo; skipped"
    return 0
  fi
  if ((same)); then
    rm -f -- "$tmp"
    return 0
  fi

  log_change "install login screen keyboard ($layout): $dest"
  # Create missing directories owned by the greeter user so it can still
  # write the rest of its own COSMIC config.
  for d in "$home/.config" "$home/.config/cosmic" "${base%/v1}" "$base"; do
    if [[ ! -d "$d" ]] && ! sudo -n test -d "$d" 2>/dev/null; then
      run_sudo install -d -o "$user" -g "$group" -m 0700 -- "$d"
    fi
  done
  if [[ -e "$dest" ]] || sudo -n test -e "$dest" 2>/dev/null; then
    run_sudo cp -p -- "$dest" "$dest.bak.$(date +%Y%m%d-%H%M%S)"
  fi
  run_sudo install -m 0644 -o "$user" -g "$group" -- "$tmp" "$dest"
  rm -f -- "$tmp"
}

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

  # Keyboard: follow the layout chosen in the installer instead of shipping one.
  _cosmic_xkb_apply "$dst/com.system76.CosmicComp/v1/xkb_config"
}
