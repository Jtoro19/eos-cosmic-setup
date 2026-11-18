#!/usr/bin/env bash
# Each scenario runs in its own subshell on purpose (SC2030/SC2031).
# shellcheck disable=SC2030,SC2031
# tests/test-greeter-xkb.sh: the login screen (cosmic-greeter) gets the same
# keyboard config as the session. Uses a fake sudo, the current user in place
# of cosmic-greeter and a temporary home, so no system state is touched.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'chmod -R u+rwX -- "$WORK" 2>/dev/null; rm -rf -- "$WORK"' EXIT

failures=0
check() { # check <description> <status>
  if (($2 == 0)); then
    printf 'ok   - %s\n' "$1"
  else
    printf 'FAIL - %s\n' "$1"
    failures=$((failures + 1))
  fi
}
check_cond() { # check_cond <description> <command...>
  local d="$1"
  shift
  if "$@"; then check "$d" 0; else check "$d" 1; fi
}

# Fake sudo that drops -n and runs the command as the current user, and one
# that always fails (no usable sudo).
mkdir -p "$WORK/bin" "$WORK/nosudo"
# shellcheck disable=SC2016  # literal script text
printf '#!/bin/sh\n[ "$1" = "-n" ] && shift\nexec "$@"\n' >"$WORK/bin/sudo"
printf '#!/bin/sh\nexit 1\n' >"$WORK/nosudo/sudo"
chmod +x "$WORK/bin/sudo" "$WORK/nosudo/sudo"

# apply <home> <dry-run 0|1> <greeter-user> [path-prefix]: run the greeter
# step in a fresh subshell and print the CHANGES count on the last line.
apply() {
  local home="$1" dry="$2" user="$3" prefix="${4:-$WORK/bin}"
  (
    export PATH="$prefix:$PATH" DRY_RUN="$dry" EOS_GREETER_USER="$user" EOS_GREETER_HOME="$home"
    # shellcheck source=lib/common.sh
    source "$REPO_ROOT/lib/common.sh"
    # shellcheck source=modules/20-cosmic-settings.sh
    source "$REPO_ROOT/modules/20-cosmic-settings.sh"
    CHANGES=0
    _cosmic_greeter_xkb_apply latam "" "" >/dev/null 2>&1
    printf '%s\n' "$CHANGES"
  )
}

home="$WORK/greeter"
mkdir -p "$home"
dest="$home/.config/cosmic/com.system76.CosmicComp/v1/xkb_config"
printf '(\n    rules: "",\n    model: "",\n    layout: "latam",\n    variant: "",\n    options: None,\n    repeat_delay: 600,\n    repeat_rate: 25,\n)' >"$WORK/expected"

n="$(apply "$home" 0 "$USER" | tail -n1)"
check_cond "creates the greeter xkb_config with the system layout" cmp -s -- "$dest" "$WORK/expected"
check_cond "counts one change on first run (got $n)" test "$n" = 1
check_cond "new directories and file belong to the greeter user" \
  test "$(stat -c %U -- "$home/.config")" = "$USER" -a "$(stat -c %U -- "$dest")" = "$USER"

n="$(apply "$home" 0 "$USER" | tail -n1)"
check_cond "second run changes nothing (got $n)" test "$n" = 0

printf 'old' >"$dest"
n="$(apply "$home" 0 "$USER" | tail -n1)"
check_cond "a different file is replaced" cmp -s -- "$dest" "$WORK/expected"
check_cond "the replaced file is backed up" test -n "$(compgen -G "$dest.bak.*")"

# Dry-run: unreadable file and no usable sudo means it cannot be compared;
# it is skipped instead of reporting a change forever.
printf 'old' >"$dest"
chmod 000 "$dest"
n="$(apply "$home" 1 "$USER" "$WORK/nosudo" | tail -n1)"
check_cond "dry-run without sudo skips an unreadable file (got $n)" test "$n" = 0
chmod 644 "$dest"

# Machines without the greeter user are left alone.
n="$(apply "" 0 "no-such-user-eos" | tail -n1)"
check_cond "no cosmic-greeter user: nothing is done (got $n)" test "$n" = 0

if ((failures > 0)); then
  printf '%d check(s) failed\n' "$failures"
  exit 1
fi
printf 'all checks passed\n'
