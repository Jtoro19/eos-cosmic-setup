#!/usr/bin/env bash
# modules/84-vesktop-mic.sh: stop Vesktop from lowering the microphone volume.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="vesktop-mic"
# shellcheck disable=SC2034
MODULE_DESC="Vesktop microphone: block its automatic gain control (PipeWire rule and Chromium flag)"
# shellcheck disable=SC2034
MODULE_OPTIN=1
# shellcheck disable=SC2034
MODULE_DEPS=""

_VESKTOP_FLAG="--disable-features=WebRtcAllowInputVolumeAdjustment"
_VESKTOP_RULE="10-block-agc.conf"
# Spanish file name used by the first hand-made version of this rule.
_VESKTOP_LEGACY_RULE="10-bloquear-agc.conf"

module_apply() {
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
  local dir="$cfg/pipewire/pipewire-pulse.conf.d"
  local before

  if ! pkg_installed vesktop && ! command -v vesktop >/dev/null 2>&1; then
    log_info "Vesktop is not installed; skipping vesktop-mic"
    return 0
  fi

  before=$CHANGES

  # Migration: keep a single rule file. The legacy one is backed up first
  # (its name does not end in .conf, so PipeWire ignores the backup).
  if [[ -f "$dir/$_VESKTOP_LEGACY_RULE" ]]; then
    log_change "remove legacy rule $dir/$_VESKTOP_LEGACY_RULE (replaced by $_VESKTOP_RULE)"
    backup_file "$dir/$_VESKTOP_LEGACY_RULE"
    run rm -f -- "$dir/$_VESKTOP_LEGACY_RULE"
  fi
  install_file "$REPO_ROOT/files/vesktop-mic/$_VESKTOP_RULE" "$dir/$_VESKTOP_RULE" 0644 || return 1

  # Reloading the audio stack is only needed when the rule changed.
  if ((CHANGES > before)); then
    run systemctl --user restart pipewire pipewire-pulse wireplumber
    log_warn "audio stack is being restarted; restart Vesktop so it reconnects"
  fi

  # Chromium flag read by the Vesktop launcher; takes effect on next start.
  ensure_line "$cfg/vesktop-flags.conf" "$_VESKTOP_FLAG"
  return 0
}
