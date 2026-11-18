#!/usr/bin/env bash
# modules/14-flatpak.sh: Flatpak with the system-wide flathub remote.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="flatpak"
# shellcheck disable=SC2034
MODULE_DESC="Flatpak and the system-wide flathub remote (apps come from the package groups)"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS=""

module_apply() {
  ensure_flathub
}
