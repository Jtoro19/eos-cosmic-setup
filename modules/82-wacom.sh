#!/usr/bin/env bash
# modules/82-wacom.sh: map Wacom tablets to an output for cosmic-comp.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="wacom"
# shellcheck disable=SC2034
MODULE_DESC="Wacom tablets: map them to an output in cosmic-comp (needed without an internal display)"
# shellcheck disable=SC2034
MODULE_OPTIN=1
# shellcheck disable=SC2034
MODULE_DEPS=""

_WACOM_INPUT_DEVICES=/proc/bus/input/devices

# _wacom_detect_names <devices-file>: print the unique names of Wacom tablet
# input devices, exactly as the kernel (and so the compositor) names them.
# Only Pen, Pad, Finger, Touch and Stylus nodes are tablet endpoints.
_wacom_detect_names() {
  [[ -r "$1" ]] || return 0
  sed -n 's/^N: Name="\(Wacom[^"]*\)"[[:space:]]*$/\1/p' "$1" |
    grep -E ' (Pen|Pad|Finger|Touch|Stylus)$' | awk '!seen[$0]++' || true
}

# _wacom_outputs: print "<name> <enabled|disabled>" per output from
# cosmic-randr. Its output carries ANSI colors even when piped; output names
# are the unindented lines. Fails when cosmic-randr is missing or has no
# session to talk to.
_wacom_outputs() {
  local raw
  command -v cosmic-randr >/dev/null 2>&1 || return 1
  raw="$(cosmic-randr list 2>/dev/null)" || return 1
  printf '%s\n' "$raw" | awk '
    { gsub(/\033\[[0-9;]*m/, "") }
    /^[^ \t]/ && match($0, /\((enabled|disabled)\)/) { print $1, substr($0, RSTART + 1, RLENGTH - 2) }'
}

# _wacom_merge <file> <output> <device-name...>: print the new content of the
# COSMIC input_devices file with every device mapped to <output>, keeping every
# other entry. The format is the one COSMIC writes: a RON map with one
#   "name": (state: Enabled, map_to_output: Some("out")),
# entry per line. A missing or empty file yields a fresh map. Returns 1 and
# prints nothing when the existing file has another shape.
_wacom_merge() {
  local file="$1" out="$2" name line i last indent="    " nl
  shift 2
  local fields found tail
  local -a lines=() result=()
  local re_entry='^([[:space:]]*)"([^"]*)":[[:space:]]*\((.*)\),?[[:space:]]*$'
  local re_state='^(.*state:[[:space:]]*)[A-Za-z]+(.*)$'
  local re_map='^(.*map_to_output:[[:space:]]*)(None|Some\("[^"]*"\))(.*)$'

  if [[ -s "$file" ]]; then
    mapfile -t lines <"$file"
  fi
  # Drop blank lines at both ends.
  while ((${#lines[@]})) && [[ -z "${lines[0]//[[:space:]]/}" ]]; do lines=("${lines[@]:1}"); done
  while ((${#lines[@]})) && [[ -z "${lines[-1]//[[:space:]]/}" ]]; do unset 'lines[-1]'; done

  if ((${#lines[@]} == 0)); then
    lines=("{" "}")
  elif ((${#lines[@]} == 1)) && [[ "${lines[0]//[[:space:]]/}" == "{}" ]]; then
    lines=("{" "}")
  fi

  # Validate the shape: "{", entry or blank lines, "}".
  nl=${#lines[@]}
  [[ "${lines[0]//[[:space:]]/}" == "{" && "${lines[nl - 1]//[[:space:]]/}" == "}" ]] || return 1
  for ((i = 1; i < nl - 1; i++)); do
    line="${lines[i]}"
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "$line" =~ $re_entry ]] || return 1
    fields="${BASH_REMATCH[3]}"
    [[ "$fields" =~ $re_state ]] || return 1
    [[ "$fields" =~ $re_map ]] || return 1
  done

  result=("${lines[@]:0:nl - 1}")
  for name in "$@"; do
    found=0
    for ((i = 1; i < ${#result[@]}; i++)); do
      line="${result[i]}"
      [[ "$line" =~ $re_entry ]] || continue
      indent="${BASH_REMATCH[1]}"
      [[ "${BASH_REMATCH[2]}" == "$name" ]] || continue
      found=1
      fields="${BASH_REMATCH[3]}"
      tail=","
      [[ "$line" =~ ,[[:space:]]*$ ]] || tail=""
      [[ "$fields" =~ $re_state ]] && fields="${BASH_REMATCH[1]}Enabled${BASH_REMATCH[2]}"
      [[ "$fields" =~ $re_map ]] && fields="${BASH_REMATCH[1]}Some(\"$out\")${BASH_REMATCH[3]}"
      result[i]="$indent\"$name\": ($fields)$tail"
      break
    done
    if ((!found)); then
      last=$((${#result[@]} - 1))
      # Entries need a separating comma; the previous last entry may lack one.
      if ((last >= 1)) && [[ ! "${result[last]}" =~ ,[[:space:]]*$ ]] &&
        [[ -n "${result[last]//[[:space:]]/}" ]]; then
        result[last]="${result[last]},"
      fi
      result+=("$indent\"$name\": (state: Enabled, map_to_output: Some(\"$out\")),")
    fi
  done
  result+=("}")
  printf '%s\n' "${result[@]}"
}

module_apply() {
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicComp/v1/input_devices"
  local out="${WACOM_OUTPUT:-}" outputs="" name existed=0 tmp rc=0
  local -a names=()

  ensure_packages libwacom libinput-tools || return 1

  mapfile -t names < <(_wacom_detect_names "$_WACOM_INPUT_DEVICES")
  if ((${#names[@]} == 0)); then
    log_info "no Wacom tablet connected; nothing to map"
    return 0
  fi

  if outputs="$(_wacom_outputs)"; then
    if [[ "${WACOM_FORCE:-0}" != "1" ]] && grep -qE '^(eDP|LVDS|DSI)-' <<<"$outputs"; then
      log_info "internal display found; mapping not needed (cosmic-comp only drops tablet events without one). Set WACOM_FORCE=1 to map anyway."
      return 0
    fi
    if [[ -z "$out" ]]; then
      out="$(awk '$2 == "enabled" { print $1; exit }' <<<"$outputs")"
    fi
  fi
  if [[ -z "$out" ]]; then
    log_warn "cannot determine an output (cosmic-randr unavailable or no enabled output); run from a COSMIC session or set WACOM_OUTPUT=<name>"
    return 0
  fi

  [[ -f "$cfg" ]] && existed=1
  tmp="$(mktemp)"
  if ! _wacom_merge "$cfg" "$out" "${names[@]}" >"$tmp"; then
    log_warn "$cfg has an unexpected format; not modifying it"
    rm -f -- "$tmp"
    return 0
  fi
  install_file "$tmp" "$cfg" 0644 || rc=$?
  rm -f -- "$tmp"
  if ((rc == 0 && !existed)); then
    log_info "tablet config for: ; if the tablet does not respond after the file is created, log out and back in"
  fi
  return "$rc"
}
