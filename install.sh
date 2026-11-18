#!/usr/bin/env bash
# install.sh: turn a fresh EndeavourOS + COSMIC install into a configured desktop.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

MODULES_DIR="$REPO_ROOT/modules"

# Parallel arrays describing discovered modules (same index = same module).
MOD_FILES=()
MOD_NAMES=()
MOD_OPTIN=()
MOD_DEPS=()
MOD_DESC=()

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --list              List available modules.
  --all               Run all non-opt-in modules.
  --only <module>     Run only this module plus its dependencies. Repeatable,
                      also accepts a comma-separated list. Opt-in modules run
                      only when named here.
  --dry-run           Show what would change without applying anything.
  -h, --help          Show this help.

Examples:
  ./install.sh --list
  ./install.sh --all --dry-run
  ./install.sh --only drivers,kitty
  ./install.sh --all --only kvm
EOF
}

# read_meta <file>: print "name|optin|deps|desc" for one module.
# Runs in a subshell so module variables and functions never leak.
read_meta() (
  # shellcheck source=/dev/null
  source "$1"
  : "${MODULE_NAME:?MODULE_NAME is not set}"
  : "${MODULE_DESC:?MODULE_DESC is not set}"
  if [[ "$(type -t module_apply || true)" != "function" ]]; then
    echo "module_apply is not defined" >&2
    exit 1
  fi
  printf '%s|%s|%s|%s\n' "$MODULE_NAME" "${MODULE_OPTIN:-0}" "${MODULE_DEPS:-}" "$MODULE_DESC"
)

load_modules() {
  local f meta name optin deps desc i
  local -a files=()

  shopt -s nullglob
  files=("$MODULES_DIR"/*.sh)
  shopt -u nullglob

  for f in "${files[@]}"; do
    if ! meta="$(read_meta "$f")"; then
      log_error "invalid module file: $f"
      return 1
    fi
    IFS='|' read -r name optin deps desc <<<"$meta"
    if [[ ! "$optin" =~ ^[01]$ ]]; then
      log_error "MODULE_OPTIN must be 0 or 1 in $f"
      return 1
    fi
    for ((i = 0; i < ${#MOD_NAMES[@]}; i++)); do
      if [[ "${MOD_NAMES[$i]}" == "$name" ]]; then
        log_error "duplicate module name '$name' in $f"
        return 1
      fi
    done
    MOD_FILES+=("$f")
    MOD_NAMES+=("$name")
    MOD_OPTIN+=("$optin")
    MOD_DEPS+=("$deps")
    MOD_DESC+=("$desc")
  done
}

# index_of <name>: print the module index, or fail when unknown.
index_of() {
  local i
  for ((i = 0; i < ${#MOD_NAMES[@]}; i++)); do
    if [[ "${MOD_NAMES[$i]}" == "$1" ]]; then
      printf '%s\n' "$i"
      return 0
    fi
  done
  return 1
}

declare -A SELECTED=()

# add_with_deps <name>: select a module and its dependencies transitively.
add_with_deps() {
  local name="$1" i dep
  local -a deps=()
  if ! i="$(index_of "$name")"; then
    log_error "unknown module: $name"
    return 1
  fi
  if [[ -n "${SELECTED[$name]:-}" ]]; then
    return 0
  fi
  SELECTED["$name"]=1
  read -ra deps <<<"${MOD_DEPS[$i]}"
  for dep in "${deps[@]}"; do
    add_with_deps "$dep" || return 1
  done
}

list_modules() {
  local i opt
  printf '%-20s %-7s %s\n' "MODULE" "OPT-IN" "DESCRIPTION"
  for ((i = 0; i < ${#MOD_NAMES[@]}; i++)); do
    opt="no"
    if [[ "${MOD_OPTIN[$i]}" == "1" ]]; then
      opt="yes"
    fi
    printf '%-20s %-7s %s\n' "${MOD_NAMES[$i]}" "$opt" "${MOD_DESC[$i]}"
  done
  if ((${#MOD_NAMES[@]} == 0)); then
    log_info "no modules found in $MODULES_DIR"
  fi
}

# run_module <file> <changes-out-file>: executed inside a subshell.
run_module() {
  local file="$1" out="$2" rc=0
  CHANGES=0
  # shellcheck source=/dev/null
  source "$file"
  module_apply || rc=$?
  printf '%s\n' "$CHANGES" >"$out"
  return "$rc"
}

# --- Argument parsing -------------------------------------------------------

ACTION=""
ALL=0
ONLY=()

add_only() {
  local p
  local -a parts=()
  IFS=',' read -ra parts <<<"$1"
  for p in "${parts[@]}"; do
    if [[ -n "$p" ]]; then
      ONLY+=("$p")
    fi
  done
}

if (($# == 0)); then
  usage
  exit 1
fi

while (($# > 0)); do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --list) ACTION="list" ;;
    --all)
      ALL=1
      ACTION="run"
      ;;
    --only)
      if (($# < 2)); then
        log_error "--only requires a module name"
        exit 2
      fi
      add_only "$2"
      ACTION="run"
      shift
      ;;
    --only=*)
      add_only "${1#--only=}"
      ACTION="run"
      ;;
    --dry-run) DRY_RUN=1 ;;
    *)
      log_error "unknown option: $1"
      usage
      exit 2
      ;;
  esac
  shift
done
export DRY_RUN

if [[ -z "$ACTION" ]]; then
  log_error "nothing to do: use --list, --all or --only <module>"
  usage
  exit 1
fi

if [[ "$EUID" -eq 0 ]]; then
  log_error "do not run as root; the installer uses sudo where needed"
  exit 1
fi

load_modules || exit 1

if [[ "$ACTION" == "list" ]]; then
  list_modules
  exit 0
fi

# --- Selection --------------------------------------------------------------

if ((ALL)); then
  for ((i = 0; i < ${#MOD_NAMES[@]}; i++)); do
    if [[ "${MOD_OPTIN[$i]}" == "0" ]]; then
      add_with_deps "${MOD_NAMES[$i]}" || exit 2
    fi
  done
fi
for name in "${ONLY[@]}"; do
  add_with_deps "$name" || exit 2
done

# --- Execution --------------------------------------------------------------

CHANGES_FILE="$(mktemp)"
trap 'rm -f -- "$CHANGES_FILE"' EXIT

declare -A BAD=()
RAN=()
FAILED_LIST=()
SKIPPED_LIST=()
TOTAL_CHANGES=0

if [[ "$DRY_RUN" == "1" ]]; then
  log_info "dry-run mode: nothing will be changed"
fi

for ((i = 0; i < ${#MOD_NAMES[@]}; i++)); do
  name="${MOD_NAMES[$i]}"
  if [[ -z "${SELECTED[$name]:-}" ]]; then
    continue
  fi

  blocker=""
  read -ra deps <<<"${MOD_DEPS[$i]}"
  for dep in "${deps[@]}"; do
    if [[ -n "${BAD[$dep]:-}" ]]; then
      blocker="$dep"
      break
    fi
  done
  if [[ -n "$blocker" ]]; then
    log_warn "skipping '$name': dependency '$blocker' failed or was skipped"
    BAD["$name"]=1
    SKIPPED_LIST+=("$name")
    continue
  fi

  log_info "module: $name"
  : >"$CHANGES_FILE"
  rc=0
  (run_module "${MOD_FILES[$i]}" "$CHANGES_FILE") || rc=$?
  n="$(<"$CHANGES_FILE")"
  if [[ ! "$n" =~ ^[0-9]+$ ]]; then
    n=0
  fi
  TOTAL_CHANGES=$((TOTAL_CHANGES + n))
  if ((rc == 0)); then
    RAN+=("$name")
    log_ok "module '$name' done"
  else
    log_error "module '$name' failed (exit $rc)"
    BAD["$name"]=1
    FAILED_LIST+=("$name")
  fi
done

# --- Summary ----------------------------------------------------------------

printf '\n'
log_info "modules run: ${#RAN[@]}${RAN[*]:+ (${RAN[*]})}"
if ((${#FAILED_LIST[@]} > 0)); then
  log_error "failed: ${FAILED_LIST[*]}"
fi
if ((${#SKIPPED_LIST[@]} > 0)); then
  log_warn "skipped: ${SKIPPED_LIST[*]}"
fi
if [[ "$DRY_RUN" == "1" ]]; then
  if ((TOTAL_CHANGES == 0)); then
    log_info "Nothing to change"
  else
    log_info "$TOTAL_CHANGES change(s) would be made"
  fi
else
  log_info "total changes: $TOTAL_CHANGES"
fi

if ((${#FAILED_LIST[@]} > 0 || ${#SKIPPED_LIST[@]} > 0)); then
  exit 1
fi
