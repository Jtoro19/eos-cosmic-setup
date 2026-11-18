#!/usr/bin/env bash
# tests/test-xkb.sh: unit tests for the COSMIC xkb_config renderer and the
# localectl parser in modules/20-cosmic-settings.sh. No system state is touched.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT
# shellcheck source=modules/20-cosmic-settings.sh
source "$REPO_ROOT/modules/20-cosmic-settings.sh"

failures=0
check() { # check <description> <status>
  if (($2 == 0)); then
    printf 'ok   - %s\n' "$1"
  else
    printf 'FAIL - %s\n' "$1"
    failures=$((failures + 1))
  fi
}

# expect_render <name> <layout> <variant> <options> <expected-file>
expect_render() {
  _cosmic_xkb_render "$2" "$3" "$4" >"$WORK/got"
  cmp -s -- "$WORK/got" "$5"
  check "$1" $?
}

# Reference sample: the live file of the reference host (no trailing newline).
printf '(\n    rules: "",\n    model: "",\n    layout: "us",\n    variant: "altgr-intl",\n    options: None,\n    repeat_delay: 600,\n    repeat_rate: 25,\n)' >"$WORK/us"
expect_render "us / altgr-intl / no options is byte-exact" us altgr-intl "" "$WORK/us"
if [[ -z "$(tail -c1 -- "$WORK/got")" ]]; then
  check "no trailing newline" 1
else
  check "no trailing newline" 0
fi

printf '(\n    rules: "",\n    model: "",\n    layout: "latam",\n    variant: "",\n    options: None,\n    repeat_delay: 600,\n    repeat_rate: 25,\n)' >"$WORK/latam"
expect_render "latam without variant" latam "" "" "$WORK/latam"

printf '(\n    rules: "",\n    model: "",\n    layout: "latam,us",\n    variant: "",\n    options: Some("grp:alt_shift_toggle"),\n    repeat_delay: 600,\n    repeat_rate: 25,\n)' >"$WORK/multi"
expect_render "latam,us with grp:alt_shift_toggle" "latam,us" "" "grp:alt_shift_toggle" "$WORK/multi"

printf '(\n    rules: "",\n    model: "",\n    layout: "a\\"b\\\\c",\n    variant: "",\n    options: None,\n    repeat_delay: 600,\n    repeat_rate: 25,\n)' >"$WORK/quote"
expect_render 'quote and backslash are escaped' 'a"b\c' "" "" "$WORK/quote"

# Parser: a fake localectl first in PATH.
mkdir -p "$WORK/bin"
fake_localectl() { # fake_localectl <body printed by localectl status>
  printf '#!/bin/sh\ncat <<'"'"'EOT'"'"'\n%s\nEOT\n' "$1" >"$WORK/bin/localectl"
  chmod +x "$WORK/bin/localectl"
}
field() { PATH="$WORK/bin:$PATH" _cosmic_xkb_field "$1"; }

fake_localectl '   System Locale: LANG=en_US.UTF-8
       VC Keymap: us
      X11 Layout: latam,us
     X11 Variant: ,intl
     X11 Options: grp:alt_shift_toggle,caps:escape'
if [[ "$(field 'X11 Layout')" == "latam,us" ]]; then check "parses a comma-list layout" 0; else check "parses a comma-list layout" 1; fi
if [[ "$(field 'X11 Variant')" == ",intl" ]]; then check "parses a variant list" 0; else check "parses a variant list" 1; fi
if [[ "$(field 'X11 Options')" == "grp:alt_shift_toggle,caps:escape" ]]; then check "parses options that contain colons" 0; else check "parses options that contain colons" 1; fi

fake_localectl '   System Locale: LANG=en_US.UTF-8
       VC Keymap: us
      X11 Layout: n/a'
if [[ -z "$(field 'X11 Layout')" && -z "$(field 'X11 Variant')" ]]; then check "n/a and absent fields are empty" 0; else check "n/a and absent fields are empty" 1; fi

# Without localectl the field is empty and the function still succeeds.
mkdir -p "$WORK/nolocalectl"
ln -s "$(command -v awk)" "$WORK/nolocalectl/awk"
out="$(PATH="$WORK/nolocalectl" _cosmic_xkb_field 'X11 Layout' 2>&1)"
if [[ -z "$out" ]]; then check "missing localectl gives an empty value" 0; else check "missing localectl gives an empty value" 1; fi

# End to end: no layout means xkb_config is left untouched and a warning shows.
# The login screen step is covered by tests/test-greeter-xkb.sh; keep it away
# from the real cosmic-greeter user here.
export EOS_GREETER_USER="no-such-user-eos" EOS_GREETER_HOME=""
log_info() { :; }
log_warn() { printf 'WARN %s\n' "$*"; }
install_file() { printf 'INSTALL %s\n' "$2"; }
dest="$WORK/xkb_config"
printf 'keep' >"$dest"
msg="$(PATH="$WORK/bin:$PATH" _cosmic_xkb_apply "$dest")"
if [[ "$msg" == WARN* && "$(<"$dest")" == "keep" ]]; then check "no X11 layout: warns and leaves the file alone" 0; else check "no X11 layout: warns and leaves the file alone" 1; fi

fake_localectl '      X11 Layout: latam'
msg="$(PATH="$WORK/bin:$PATH" _cosmic_xkb_apply "$dest")"
if [[ "$msg" == "INSTALL $dest" ]]; then check "with a layout it installs the rendered file" 0; else check "with a layout it installs the rendered file" 1; fi

if ((failures > 0)); then
  printf '%d check(s) failed\n' "$failures"
  exit 1
fi
printf 'all checks passed\n'
