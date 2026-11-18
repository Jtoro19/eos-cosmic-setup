#!/usr/bin/env bash
# modules/08-locale.sh: system language, regional formats and keyboard layout.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="locale"
# shellcheck disable=SC2034
MODULE_DESC="locale: English UI with Colombian formats, us/altgr-intl keyboard (time zone only if LOCALE_TZ is set)"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS=""

_LOCALE_GEN=("en_US.UTF-8 UTF-8" "es_CO.UTF-8 UTF-8")
_LOCALE_KEYMAP="us"
_LOCALE_XKB_LAYOUT="us"
_LOCALE_XKB_VARIANT="altgr-intl"

# _locale_gen_render <src>: print locale.gen with the wanted locales uncommented.
_locale_gen_render() {
  local wanted
  wanted="$(printf '%s\n' "${_LOCALE_GEN[@]}")"
  WANTED="$wanted" awk '
    BEGIN { n = split(ENVIRON["WANTED"], w, "\n"); for (i = 1; i <= n; i++) if (w[i] != "") want[w[i]] = 1 }
    { line = $0; sub(/^#[ \t]*/, "", line) }
    (line in want) && !(line in done) { print line; done[line] = 1; next }
    { print }
    END { for (k in want) if (!(k in done)) print k }
  ' "$1"
}

# _locale_status <field>: value of a `localectl status` field, for example
# "VC Keymap" or "X11 Variant"; empty when unset.
_locale_status() {
  localectl status 2>/dev/null | awk -v f="$1" -F': ' '
    { key = $1; sub(/^[ \t]+/, "", key) }
    key == f { print $2; exit }'
}

module_apply() {
  local tmp gen_before gen_after tz

  # Locales to generate.
  if [[ -f /etc/locale.gen ]]; then
    gen_before="$(cksum </etc/locale.gen)"
    tmp="$(mktemp)"
    _locale_gen_render /etc/locale.gen >"$tmp"
    if ! cmp -s -- "$tmp" /etc/locale.gen; then
      install_file "$tmp" /etc/locale.gen 0644
      gen_after="changed"
    else
      gen_after="$gen_before"
    fi
    rm -f -- "$tmp"
    if [[ "$gen_after" != "$gen_before" ]]; then
      run_sudo locale-gen
    fi
  fi

  # LANG in English, regional formats (dates, numbers, money, paper) in es_CO.
  install_file "$REPO_ROOT/files/locale/locale.conf" /etc/locale.conf 0644

  # Console keymap and the X11/XKB layout used by the greeter.
  if [[ "$(_locale_status 'VC Keymap')" != "$_LOCALE_KEYMAP" ]]; then
    log_change "set console keymap: $_LOCALE_KEYMAP"
    run_sudo localectl set-keymap --no-convert "$_LOCALE_KEYMAP"
  fi
  if [[ "$(_locale_status 'X11 Layout')" != "$_LOCALE_XKB_LAYOUT" ||
    "$(_locale_status 'X11 Variant')" != "$_LOCALE_XKB_VARIANT" ]]; then
    log_change "set X11 keyboard: $_LOCALE_XKB_LAYOUT ($_LOCALE_XKB_VARIANT)"
    run_sudo localectl set-x11-keymap --no-convert "$_LOCALE_XKB_LAYOUT" "" "$_LOCALE_XKB_VARIANT"
  fi

  # Time zone: the installer already asked for it, so only on request.
  tz="${LOCALE_TZ:-}"
  if [[ -n "$tz" ]]; then
    if [[ ! -e "/usr/share/zoneinfo/$tz" ]]; then
      log_error "unknown time zone: $tz"
      return 1
    fi
    if [[ "$(timedatectl show -p Timezone --value 2>/dev/null)" != "$tz" ]]; then
      log_change "set time zone: $tz"
      run_sudo timedatectl set-timezone "$tz"
    fi
  fi
}
