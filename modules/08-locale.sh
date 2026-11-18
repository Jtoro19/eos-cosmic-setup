#!/usr/bin/env bash
# modules/08-locale.sh: system language and regional formats.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="locale"
# shellcheck disable=SC2034
MODULE_DESC="locale: English UI with Colombian formats (keyboard and time zone are kept; time zone only if LOCALE_TZ is set)"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS=""

_LOCALE_GEN=("en_US.UTF-8 UTF-8" "es_CO.UTF-8 UTF-8")

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

  # The keyboard layout is not touched: the EndeavourOS installer already set
  # it. Time zone: the installer already asked for it, so only on request.
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
