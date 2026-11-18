# Modules

Each module is one file `modules/NN-name.sh`, where `NN` is a two-digit order
prefix (for example `10-base.sh`). `install.sh` discovers every `modules/*.sh`,
sorted by file name. See `modules/40-kitty.sh` for a reference module.

## Contract

When sourced, a module must define:

| Name | Type | Meaning |
|------|------|---------|
| `MODULE_NAME` | string | Short name used by `--only` and `MODULE_DEPS` (for example `base`). Must be unique. |
| `MODULE_DESC` | string | One-line description shown by `--list`. |
| `MODULE_OPTIN` | `0` or `1` | `1` means the module is skipped by `--all` and runs only when named with `--only`. |
| `MODULE_DEPS` | string | Space-separated module names this module needs. May be empty. |
| `module_apply` | function | Does the work. Return non-zero on failure. |

Modules are sourced in a subshell, so their variables and functions never leak
between modules. A module must not source `lib/common.sh` itself: the helpers
are already loaded by `install.sh`. A module must not call `exit` itself (the
helpers do, see fail-fast below).

## Fail-fast contract

Each module runs in its own subshell with `set -e` active, and `module_apply` is
called plainly, so a module stops at its first failed command and the installer
marks it failed (dependent modules are skipped, the final exit status is
non-zero). Do not guard commands with `|| true` unless failure is truly fine.

Some helpers are called as `helper || return 1`, which makes bash ignore `set -e`
inside the helper. So `run` and `run_sudo` are fail-fast on their own: on a
non-zero status in a real run they log `command failed (exit N): <cmd>` and
`exit` with that status, which ends only the current module. A call site that
really tolerates failure uses `run_may_fail` / `run_sudo_may_fail`: same as
`run` / `run_sudo`, but they return the status and the caller handles it, for
example `run_may_fail gtk-update-icon-cache ... || true`. Both are dry-run aware.

Real runs use `sudo -n` (through `run_sudo`, or write `sudo -n` yourself when
you must call sudo directly): the installer asks for the password once at the
start, so an expired timestamp must fail fast and never prompt. Nothing may wait
for input: use `--noconfirm`/`-y`, run builds with `</dev/null` and set
`GIT_TERMINAL_PROMPT=0` for git (already exported by `install.sh`).

## Test-only environment variables

- `EOS_MODULES_DIR=<dir>`: make `install.sh` read modules from another directory
  (used by `tests/` with fake modules). Never set it in a real run.
- `EOS_SKIP_SUDO=1`: skip the initial `sudo -v` so tests can run a real (not
  dry-run) pass without sudo. Never set it in a real run.

Run `tests/run-tests.sh` after changing `install.sh` or `lib/common.sh`.

Module files only define metadata and `module_apply` at the top level. They
must not perform any action when sourced (the installer sources them just to
list them).

## Using the helpers

Do all work through the helpers in `lib/common.sh` (`run`, `run_sudo`,
`run_may_fail`, `run_sudo_may_fail`,
`install_file`, `ensure_line`, `ensure_block`, `ensure_packages`,
`ensure_aur_packages`, `ensure_user_unit_enabled`, `detect_cpu_vendor`,
`detect_gpu_vendors`, logging functions). They provide dry-run support and
idempotency automatically. Do not call `cp`, `tee`, `pacman` or `systemctl`
directly for changes.

## Idempotency and backups

- Running a module twice must change nothing the second time.
- Check state first, act only when needed, and call `log_change` (directly or
  through a helper) once per real change.
- Any existing file that is modified is first copied to
  `<path>.bak.<YYYYmmdd-HHMMSS>` (the helpers do this).
- Never hardcode `/home/<user>` or a uid: use `$HOME`, `$USER` and
  `$XDG_RUNTIME_DIR`.
- Detect hardware (CPU and GPU vendor) at run time instead of assuming a machine.

## Opt-in modules

Set `MODULE_OPTIN=1` for anything machine-specific or intrusive (for example
virtualization, tablets, bootloader). `--all` skips them; `--only <name>` runs
them. An opt-in module that is a dependency of a selected module is pulled in
automatically.

## Specs

Every module has a spec in `specs/<name>.md`, written from the template in
`specs/README.md`, before the module is implemented.
