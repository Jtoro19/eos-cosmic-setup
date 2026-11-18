#!/usr/bin/env bash
# lib/common.sh: shared helpers for install.sh and modules.
#
# This file is sourced, never executed. It deliberately does not set shell
# options: the caller (install.sh) owns `set -euo pipefail`.

# --- Globals ----------------------------------------------------------------

# Repository root, resolved from this file's location (lib/..).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# 1 = print what would happen, change nothing.
DRY_RUN="${DRY_RUN:-0}"
export DRY_RUN

# Number of changes made (or that would be made in dry-run).
CHANGES=0

# Files already backed up during this process (one backup per file per run).
declare -A _BACKED_UP=()

# --- Logging ----------------------------------------------------------------

_C_RESET="" _C_BLUE="" _C_GREEN="" _C_YELLOW="" _C_RED="" _C_CYAN=""
if [[ -t 1 ]]; then
  _C_RESET=$'\033[0m'
  _C_BLUE=$'\033[34m'
  _C_GREEN=$'\033[32m'
  _C_YELLOW=$'\033[33m'
  _C_RED=$'\033[31m'
  _C_CYAN=$'\033[36m'
fi

log_info() { printf '%s[info]%s %s\n' "$_C_BLUE" "$_C_RESET" "$*"; }
log_ok() { printf '%s[ok]%s %s\n' "$_C_GREEN" "$_C_RESET" "$*"; }
log_warn() { printf '%s[warn]%s %s\n' "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
log_error() { printf '%s[error]%s %s\n' "$_C_RED" "$_C_RESET" "$*" >&2; }

# Records one change and prints it. When install.sh set _EOS_CHANGES_FILE the
# running count is mirrored there, so a module that fails (and so exits early)
# still reports the changes it made. A module's own EXIT trap cannot lose it.
log_change() {
  CHANGES=$((CHANGES + 1))
  printf '%s[change]%s %s\n' "$_C_CYAN" "$_C_RESET" "$*"
  if [[ -n "${_EOS_CHANGES_FILE:-}" ]]; then
    printf '%s\n' "$CHANGES" >"$_EOS_CHANGES_FILE" 2>/dev/null || true
  fi
}

# --- Command execution ------------------------------------------------------

# Contract: run and run_sudo are FAIL-FAST. A module runs in its own subshell,
# so on a failed command they log it and `exit` with its status, which ends
# only that module. This holds even when the caller is inside `helper || ...`
# (where bash turns errexit off). Use run_may_fail / run_sudo_may_fail at a
# call site that really tolerates failure and handle the status there.

# run_may_fail <cmd...>: execute, or only print in dry-run mode. Returns the
# command's status instead of exiting.
run_may_fail() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] would run: %s\n' "$*"
    return 0
  fi
  "$@"
}

# run <cmd...>: like run_may_fail, but a non-zero status ends the module.
run() {
  local rc=0
  run_may_fail "$@" || rc=$?
  if ((rc != 0)); then
    log_error "command failed (exit $rc): $*"
    exit "$rc"
  fi
}

# run_sudo_may_fail <cmd...>: like run_may_fail, prefixed with sudo. Real runs
# use `sudo -n` so an expired timestamp fails at once instead of prompting
# (install.sh keeps the timestamp fresh after asking for the password once).
run_sudo_may_fail() {
  if [[ "$DRY_RUN" == "1" ]]; then
    run_may_fail sudo "$@"
  else
    run_may_fail sudo -n "$@"
  fi
}

# run_sudo <cmd...>: like run, prefixed with sudo (fail-fast).
run_sudo() {
  local rc=0
  run_sudo_may_fail "$@" || rc=$?
  if ((rc != 0)); then
    log_error "command failed (exit $rc): sudo $*"
    exit "$rc"
  fi
}

# _needs_sudo <path>: true when the path (or its nearest existing parent)
# is not writable by the current user.
_needs_sudo() {
  local p="$1"
  if [[ -e "$p" && ! -w "$p" ]]; then
    return 0
  fi
  while [[ ! -e "$p" ]]; do
    p="$(dirname "$p")"
  done
  [[ -w "$p" ]] && return 1
  return 0
}

# _priv_run <target-path> <cmd...>: run, with sudo only when the target
# location is not writable by the current user.
_priv_run() {
  local target="$1"
  shift
  if _needs_sudo "$target"; then
    run_sudo "$@"
  else
    run "$@"
  fi
}

# --- File helpers -----------------------------------------------------------

# backup_file <path>: copy to <path>.bak.<YYYYmmdd-HHMMSS>, once per run.
backup_file() {
  local path="$1" ts
  [[ -e "$path" ]] || return 0
  if [[ -n "${_BACKED_UP[$path]:-}" ]]; then
    return 0
  fi
  _BACKED_UP["$path"]=1
  ts="$(date +%Y%m%d-%H%M%S)"
  _priv_run "$path" cp -p -- "$path" "$path.bak.$ts"
}

# install_file <src> <dest> [mode]: idempotent file install with backup.
install_file() {
  local src="$1" dest="$2" mode="${3:-0644}"
  if [[ ! -f "$src" ]]; then
    log_error "install_file: source not found: $src"
    return 1
  fi
  if [[ -f "$dest" ]] && cmp -s -- "$src" "$dest"; then
    return 0
  fi
  log_change "install $dest"
  backup_file "$dest"
  _priv_run "$dest" mkdir -p -- "$(dirname "$dest")"
  _priv_run "$dest" install -m "$mode" -- "$src" "$dest"
}

# install_template <src.in> <dest> [mode]: render @HOME@ and @USER@ in the
# template into a temp file, then install it with install_file (so backup,
# idempotency and dry-run behave the same). Uses bash parameter expansion, so
# paths with special characters (including "&") are substituted literally.
install_template() {
  local src="$1" dest="$2" mode="${3:-0644}" tmp content rc=0
  if [[ ! -f "$src" ]]; then
    log_error "install_template: source not found: $src"
    return 1
  fi
  tmp="$(mktemp)"
  # The sentinel keeps trailing newlines intact through command substitution.
  content="$(
    cat -- "$src"
    printf x
  )"
  content="${content%x}"
  content="${content//@HOME@/"$HOME"}"
  content="${content//@USER@/"${USER:-$(id -un)}"}"
  printf '%s' "$content" >"$tmp"
  install_file "$tmp" "$dest" "$mode" || rc=$?
  rm -f -- "$tmp"
  return "$rc"
}

# ensure_line <file> <line>: append the line only if not already present.
ensure_line() {
  local file="$1" line="$2" prefix=""
  if [[ -f "$file" ]] && grep -qxF -- "$line" "$file"; then
    return 0
  fi
  log_change "add line to $file: $line"
  backup_file "$file"
  _priv_run "$file" mkdir -p -- "$(dirname "$file")"
  if [[ -s "$file" && -n "$(tail -c1 -- "$file")" ]]; then
    prefix=$'\n'
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    return 0
  fi
  if _needs_sudo "$file"; then
    printf '%s%s\n' "$prefix" "$line" | sudo -n tee -a -- "$file" >/dev/null
  else
    printf '%s%s\n' "$prefix" "$line" >>"$file"
  fi
}

# ensure_block <file> <marker-name> <content>: manage a delimited block.
ensure_block() {
  local file="$1" name="$2" content="$3"
  local begin="# >>> eos-cosmic-setup:${name} >>>"
  local end="# <<< eos-cosmic-setup:${name} <<<"
  local tmp current mode="0644" action

  tmp="$(mktemp)"

  if [[ -f "$file" ]] && grep -qxF -- "$begin" "$file"; then
    current="$(awk -v b="$begin" -v e="$end" \
      '$0 == e { f = 0 } f { print } $0 == b { f = 1 }' "$file")"
    if [[ "$current" == "$content" ]]; then
      rm -f -- "$tmp"
      return 0
    fi
    action="update"
    BLOCK="$content" awk -v b="$begin" -v e="$end" '
      $0 == b {
        if (!done) { print b; print ENVIRON["BLOCK"]; print e; done = 1 }
        inblock = 1
        next
      }
      inblock { if ($0 == e) { inblock = 0 } next }
      { print }
    ' "$file" >"$tmp"
  else
    action="add"
    if [[ -f "$file" ]]; then
      cp -- "$file" "$tmp"
      if [[ -s "$tmp" && -n "$(tail -c1 -- "$tmp")" ]]; then
        printf '\n' >>"$tmp"
      fi
    fi
    printf '%s\n%s\n%s\n' "$begin" "$content" "$end" >>"$tmp"
  fi

  if [[ -f "$file" ]]; then
    mode="$(stat -c %a -- "$file")"
  fi
  log_change "$action block '$name' in $file"
  backup_file "$file"
  _priv_run "$file" mkdir -p -- "$(dirname "$file")"
  _priv_run "$file" install -m "$mode" -- "$tmp" "$file"
  rm -f -- "$tmp"
}

# --- Packages ---------------------------------------------------------------

pkg_installed() {
  pacman -Qq -- "$1" >/dev/null 2>&1
}

# ensure_packages <pkg...>: install only the missing official packages.
ensure_packages() {
  local pkg
  local -a missing=()
  for pkg in "$@"; do
    if ! pkg_installed "$pkg"; then
      missing+=("$pkg")
    fi
  done
  if ((${#missing[@]} == 0)); then
    return 0
  fi
  log_change "install packages: ${missing[*]}"
  run_sudo pacman -S --needed --noconfirm "${missing[@]}"
}

# ensure_aur_packages <pkg...>: install only the missing AUR packages (yay).
ensure_aur_packages() {
  local pkg
  local -a missing=()
  if ! command -v yay >/dev/null 2>&1; then
    log_error "yay is required for AUR packages: $*"
    return 1
  fi
  for pkg in "$@"; do
    if ! pkg_installed "$pkg"; then
      missing+=("$pkg")
    fi
  done
  if ((${#missing[@]} == 0)); then
    return 0
  fi
  log_change "install AUR packages: ${missing[*]}"
  # Answer yay's clean/diff/edit menus up front so it never stops to ask, and
  # keep the sudo timestamp alive during long builds (--sudoloop). stdin is
  # closed so nothing can wait for a keypress.
  run yay -S --needed --noconfirm --sudoloop --answerclean None --answerdiff None \
    --answeredit None --removemake "${missing[@]}" </dev/null
}

# _read_package_file <file>: print one package per line, dropping comments
# (whole-line or trailing) and blank lines. Prints nothing when missing.
_read_package_file() {
  [[ -f "$1" ]] || return 0
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//' -- "$1" | grep -v '^$' || true
}

# install_package_list <group>: install files/packages/<group>.pacman with
# ensure_packages and files/packages/<group>.aur with ensure_aur_packages.
# Only missing packages are passed on (pacman -Qq counts dependencies as
# installed). A group that lists AUR packages needs yay, but only when one of
# them is actually missing. Returns non-zero on any failure.
install_package_list() {
  local group="$1" dir="$REPO_ROOT/files/packages" pkg
  local -a pac=() aur=() fp=() missing=()
  if [[ ! -f "$dir/$group.pacman" && ! -f "$dir/$group.aur" && ! -f "$dir/$group.flatpak" ]]; then
    log_error "install_package_list: no package list for group '$group'"
    return 1
  fi
  mapfile -t pac < <(_read_package_file "$dir/$group.pacman")
  mapfile -t aur < <(_read_package_file "$dir/$group.aur")
  mapfile -t fp < <(_read_package_file "$dir/$group.flatpak")
  if ((${#fp[@]} > 0)); then
    ensure_flatpaks "${fp[@]}" || return 1
  fi

  if ((${#pac[@]} > 0)); then
    ensure_packages "${pac[@]}" || return 1
  fi
  if ((${#aur[@]} > 0)); then
    for pkg in "${aur[@]}"; do
      if ! pkg_installed "$pkg"; then
        missing+=("$pkg")
      fi
    done
    if ((${#missing[@]} > 0)); then
      ensure_aur_packages "${missing[@]}" || return 1
    fi
  fi
}

# --- Flatpak ----------------------------------------------------------------

# ensure_flathub: flatpak installed and the system-wide flathub remote added.
ensure_flathub() {
  ensure_packages flatpak || return 1
  if ! flatpak remotes --system --columns=name 2>/dev/null | grep -qx flathub; then
    log_change "add system Flatpak remote flathub"
    run_sudo flatpak remote-add --if-not-exists --system flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo
  fi
}

# ensure_flatpaks <app-id...>: install missing apps system-wide from flathub.
ensure_flatpaks() {
  local app
  local -a missing=()
  ensure_flathub || return 1
  for app in "$@"; do
    if ! flatpak info --system "$app" >/dev/null 2>&1; then
      missing+=("$app")
    fi
  done
  ((${#missing[@]} > 0)) || return 0
  log_change "install Flatpak apps (system): ${missing[*]}"
  run_sudo flatpak install --system -y --noninteractive flathub "${missing[@]}"
}

# --- systemd user units -----------------------------------------------------

user_unit_enabled() {
  systemctl --user is-enabled --quiet "$1" >/dev/null 2>&1
}

ensure_user_unit_enabled() {
  local unit="$1"
  if user_unit_enabled "$unit"; then
    return 0
  fi
  log_change "enable user unit: $unit"
  run systemctl --user daemon-reload
  run systemctl --user enable --now "$unit"
}

# system_unit_exists <unit>: true when systemd knows the unit file.
system_unit_exists() {
  [[ -n "$(systemctl list-unit-files --no-legend -- "$1" 2>/dev/null)" ]]
}

# ensure_system_unit_enabled <unit>: enable and start a system unit only when
# its unit file exists and it is not enabled yet. Read-only check.
ensure_system_unit_enabled() {
  local unit="$1"
  system_unit_exists "$unit" || return 0
  if systemctl is-enabled --quiet -- "$unit" >/dev/null 2>&1; then
    return 0
  fi
  log_change "enable system unit: $unit"
  run_sudo systemctl enable --now -- "$unit"
}

# ensure_user_in_group <group>: add $USER to an existing group. Takes effect
# after the next login. Read-only check.
ensure_user_in_group() {
  local group="$1"
  getent group "$group" >/dev/null 2>&1 || return 0
  if id -nG "$USER" | tr ' ' '\n' | grep -qx -- "$group"; then
    return 0
  fi
  log_change "add $USER to group $group (re-login needed)"
  run_sudo usermod -aG "$group" "$USER"
}

# --- Hardware detection -----------------------------------------------------

# detect_cpu_vendor: prints amd, intel or unknown.
detect_cpu_vendor() {
  local vendor=""
  if [[ -r /proc/cpuinfo ]]; then
    vendor="$(grep -m1 '^vendor_id' /proc/cpuinfo || true)"
  fi
  case "$vendor" in
    *AuthenticAMD*) printf 'amd\n' ;;
    *GenuineIntel*) printf 'intel\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

# detect_gpu_vendors: prints space-separated list of amd, intel, nvidia.
detect_gpu_vendors() {
  local lines id amd=0 intel=0 nvidia=0
  local -a out=()
  if ! command -v lspci >/dev/null 2>&1; then
    printf '\n'
    return 0
  fi
  lines="$(lspci -nn | grep -E 'VGA|3D|Display' || true)"
  while IFS= read -r id; do
    case "$id" in
      '[1002:'*) amd=1 ;;
      '[8086:'*) intel=1 ;;
      '[10de:'*) nvidia=1 ;;
      *) ;;
    esac
  done < <(printf '%s\n' "$lines" | grep -Eo '\[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\]' | tr 'A-F' 'a-f' || true)
  if ((amd)); then out+=(amd); fi
  if ((intel)); then out+=(intel); fi
  if ((nvidia)); then out+=(nvidia); fi
  printf '%s\n' "${out[*]:-}"
}

# --- Line and INI helpers ---------------------------------------------------

# remove_line <file> <exact-line> [preceding-line]: remove every occurrence of
# the exact line found OUTSIDE eos-cosmic-setup managed blocks. When
# preceding-line is given, the line immediately above is removed too if it
# matches exactly. Backs up first; counts as one change; dry-run aware.
remove_line() {
  local file="$1" line="$2" prev="${3:-}" tmp mode
  [[ -f "$file" ]] || return 0
  tmp="$(mktemp)"
  LINE="$line" PREV="$prev" awk '
    BEGIN { line = ENVIRON["LINE"]; prev = ENVIRON["PREV"] }
    /^# >>> eos-cosmic-setup:/ { inb = 1 }
    { n++; txt[n] = $0; blk[n] = inb }
    /^# <<< eos-cosmic-setup:/ { inb = 0 }
    END {
      for (i = 1; i <= n; i++) del[i] = 0
      for (i = 1; i <= n; i++) {
        if (!blk[i] && txt[i] == line) {
          del[i] = 1
          if (prev != "" && i > 1 && !blk[i-1] && txt[i-1] == prev) del[i-1] = 1
        }
      }
      for (i = 1; i <= n; i++) if (!del[i]) print txt[i]
    }
  ' "$file" >"$tmp"
  if cmp -s -- "$file" "$tmp"; then
    rm -f -- "$tmp"
    return 0
  fi
  mode="$(stat -c %a -- "$file")"
  log_change "remove legacy line from $file: $line"
  backup_file "$file"
  _priv_run "$file" install -m "$mode" -- "$tmp" "$file"
  rm -f -- "$tmp"
}

# remove_exact_block <file> <multiline-text>: remove the first exact contiguous
# occurrence of the given lines found OUTSIDE eos-cosmic-setup managed blocks.
# Other occurrences are kept. Backs up first; counts as one change; dry-run
# aware. Does nothing when the file or the text is missing.
remove_exact_block() {
  local file="$1" text="$2" tmp mode
  [[ -f "$file" && -n "$text" ]] || return 0
  tmp="$(mktemp)"
  TEXT="$text" awk '
    BEGIN { m = split(ENVIRON["TEXT"], pat, "\n") }
    /^# >>> eos-cosmic-setup:/ { inb = 1 }
    { n++; txt[n] = $0; blk[n] = inb }
    /^# <<< eos-cosmic-setup:/ { inb = 0 }
    END {
      start = 0
      for (i = 1; i + m - 1 <= n && !start; i++) {
        ok = 1
        for (j = 1; j <= m; j++) {
          if (blk[i+j-1] || txt[i+j-1] != pat[j]) { ok = 0; break }
        }
        if (ok) start = i
      }
      for (i = 1; i <= n; i++) {
        if (start && i >= start && i < start + m) continue
        print txt[i]
      }
    }
  ' "$file" >"$tmp"
  if cmp -s -- "$file" "$tmp"; then
    rm -f -- "$tmp"
    return 0
  fi
  mode="$(stat -c %a -- "$file")"
  log_change "remove legacy block from $file: ${text%%$'\n'*} ..."
  backup_file "$file"
  _priv_run "$file" install -m "$mode" -- "$tmp" "$file"
  rm -f -- "$tmp"
}

# ensure_ini_line <file> <section> <key=value>: make sure the exact line is
# present under [section]. Creates the file or section when missing. If the
# key already exists with a different value, warn and leave it alone, unless
# the optional 4th argument is "replace", which rewrites that key in place.
ensure_ini_line() {
  local file="$1" section="$2" entry="$3" policy="${4:-keep}" key tmp mode="0644" state
  key="${entry%%=*}"
  tmp="$(mktemp)"
  if [[ -f "$file" ]]; then
    state="$(SEC="[$section]" ENTRY="$entry" KEY="$key" awk '
      BEGIN { sec = ENVIRON["SEC"]; e = ENVIRON["ENTRY"]; k = ENVIRON["KEY"] }
      /^\[/ { cur = ($0 == sec) }
      cur && $0 == e { print "present"; exit }
      cur && index($0, k "=") == 1 { print "conflict"; exit }
    ' "$file")"
    if [[ "$state" == "present" ]]; then
      rm -f -- "$tmp"
      return 0
    fi
    if [[ "$state" == "conflict" && "$policy" != "replace" ]]; then
      log_warn "$file: key '$key' under [$section] has another value; leaving it"
      rm -f -- "$tmp"
      return 0
    fi
    if [[ "$state" == "conflict" ]]; then
      # policy=replace: rewrite the first matching key in the section.
      SEC="[$section]" ENTRY="$entry" KEY="$key" awk '
        BEGIN { sec = ENVIRON["SEC"]; e = ENVIRON["ENTRY"]; k = ENVIRON["KEY"] }
        /^\[/ { cur = ($0 == sec) }
        cur && !done && index($0, k "=") == 1 { print e; done = 1; next }
        { print }
      ' "$file" >"$tmp"
      mode="$(stat -c %a -- "$file")"
      log_change "set '$entry' under [$section] in $file"
      backup_file "$file"
      _priv_run "$file" install -m "$mode" -- "$tmp" "$file"
      rm -f -- "$tmp"
      return 0
    fi
    SEC="[$section]" ENTRY="$entry" awk '
      BEGIN { sec = ENVIRON["SEC"]; e = ENVIRON["ENTRY"] }
      { print }
      $0 == sec && !done { print e; done = 1; found = 1 }
      END { if (!found) { print ""; print sec; print e } }
    ' "$file" >"$tmp"
    mode="$(stat -c %a -- "$file")"
  else
    printf '[%s]\n%s\n' "$section" "$entry" >"$tmp"
  fi
  log_change "add '$entry' under [$section] in $file"
  backup_file "$file"
  _priv_run "$file" mkdir -p -- "$(dirname "$file")"
  _priv_run "$file" install -m "$mode" -- "$tmp" "$file"
  rm -f -- "$tmp"
}

# --- GSettings --------------------------------------------------------------

# ensure_gsetting <schema> <key> <value>: set a GSettings key only when the
# current value differs. <value> uses gsettings' printed form (strings keep
# their single quotes, for example "'prefer-dark'"). When gsettings or the
# session bus is unavailable, warn and skip without failing. Read-only check,
# so dry-run is accurate.
ensure_gsetting() {
  local schema="$1" key="$2" value="$3" current
  if ! command -v gsettings >/dev/null 2>&1; then
    log_warn "gsettings not found; skipping $schema $key"
    return 0
  fi
  if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" && ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/bus" ]]; then
    log_warn "no session bus; skipping $schema $key (run from a desktop session)"
    return 0
  fi
  if ! current="$(gsettings get "$schema" "$key" 2>/dev/null)"; then
    log_warn "cannot read $schema $key; skipping"
    return 0
  fi
  if [[ "$current" == "$value" ]]; then
    return 0
  fi
  log_change "gsettings set $schema $key $value (was $current)"
  run gsettings set "$schema" "$key" "$value"
}
