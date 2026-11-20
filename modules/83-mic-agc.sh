#!/usr/bin/env bash
# modules/83-mic-agc.sh: stop browsers and Electron apps from moving the microphone volume.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="mic-agc"
# shellcheck disable=SC2034
MODULE_DESC="Microphone: block automatic gain control from browsers and Electron apps (PipeWire rule)"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS=""

_MIC_AGC_RULE="20-block-mic-agc.conf"
# File name of the first hand-made version of this rule.
_MIC_AGC_LEGACY_RULE="99-block-mic-agc.conf"

module_apply() {
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
  local dir="$cfg/pipewire/pipewire-pulse.conf.d"
  local before=$CHANGES

  # Migration: keep a single rule file. The backup does not end in .conf,
  # so PipeWire ignores it.
  if [[ -f "$dir/$_MIC_AGC_LEGACY_RULE" ]]; then
    log_change "remove legacy rule $dir/$_MIC_AGC_LEGACY_RULE (replaced by $_MIC_AGC_RULE)"
    backup_file "$dir/$_MIC_AGC_LEGACY_RULE"
    run rm -f -- "$dir/$_MIC_AGC_LEGACY_RULE"
  fi
  install_file "$REPO_ROOT/files/mic-agc/$_MIC_AGC_RULE" "$dir/$_MIC_AGC_RULE" 0644 || return 1

  # Reloading the audio stack is only needed when the rule changed, and only
  # when a user PipeWire is running (not on a fresh install before login).
  if ((CHANGES > before)); then
    if systemctl --user is-active --quiet pipewire-pulse.socket pipewire-pulse.service 2>/dev/null; then
      run systemctl --user restart pipewire pipewire-pulse wireplumber
      log_warn "audio stack restarted: restart apps that were using audio"
      log_warn "if the COSMIC sound applet shows 'No device selected', run: RESYNC_DELAY=0 ~/.local/bin/cosmic-audio-resync"
    else
      log_info "PipeWire is not running; the rule applies at next login"
    fi
  fi
  return 0
}
