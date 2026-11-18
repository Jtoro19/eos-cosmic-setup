#!/usr/bin/env bash
# modules/05-pacman-conf.sh: pacman options and the multilib repository.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="pacman-conf"
# shellcheck disable=SC2034
MODULE_DESC="pacman.conf: Color, ILoveCandy, VerbosePkgLists, ParallelDownloads, multilib"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS=""

# Wanted [options] lines. Keys are matched commented or not, with any value.
_PACMAN_OPTIONS=(
  "Color"
  "ILoveCandy"
  "VerbosePkgLists"
  "ParallelDownloads = 5"
)

# _pacman_conf_render <src>: print pacman.conf with the wanted options and
# multilib enabled. Everything else is copied unchanged.
_pacman_conf_render() {
  local wanted
  wanted="$(printf '%s\n' "${_PACMAN_OPTIONS[@]}")"
  WANTED="$wanted" awk '
    function key(s) { sub(/^#[ \t]*/, "", s); sub(/[ \t]*=.*$/, "", s); sub(/[ \t]+$/, "", s); return s }
    BEGIN {
      n = split(ENVIRON["WANTED"], w, "\n")
      for (i = 1; i <= n; i++) if (w[i] != "") { want[key(w[i])] = w[i]; order[++m] = key(w[i]) }
    }
    # Leaving [options]: add wanted options that were not found.
    /^\[/ && sect == "options" {
      for (i = 1; i <= m; i++) if (!(order[i] in done)) { print want[order[i]]; done[order[i]] = 1 }
    }
    /^\[.*\][ \t]*$/ { sect = $0; gsub(/[][ \t]/, "", sect); ml = 0 }
    # Commented multilib header and its Include line.
    /^#[ \t]*\[multilib\][ \t]*$/ { print "[multilib]"; sect = "multilib"; ml = 1; next }
    ml && /^#[ \t]*Include[ \t]*=/ { sub(/^#[ \t]*/, ""); print; ml = 0; next }
    sect == "options" {
      k = key($0)
      if ((k in want) && !(k in done) && ($0 ~ /^#?[ \t]*[A-Za-z]+([ \t]*=.*)?[ \t]*$/)) {
        print want[k]; done[k] = 1; next
      }
    }
    { print }
  ' "$1"
}

module_apply() {
  local conf=/etc/pacman.conf tmp had_multilib=0
  if [[ ! -f "$conf" ]]; then
    log_warn "$conf not found; skipping"
    return 0
  fi
  grep -qx '\[multilib\]' "$conf" && had_multilib=1

  tmp="$(mktemp)"
  _pacman_conf_render "$conf" >"$tmp"
  install_file "$tmp" "$conf" 0644
  rm -f -- "$tmp"

  # A newly enabled repository needs fresh sync databases. A full upgrade
  # (not -Sy alone) avoids a partial upgrade on the packages installed next.
  if ((!had_multilib)) && _pacman_conf_render "$conf" | grep -qx '\[multilib\]'; then
    run_sudo pacman -Syu --noconfirm
  fi
}
