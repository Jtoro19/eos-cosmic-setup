#!/usr/bin/env bash
# modules/17-packages-gaming.sh: Gaming (Steam, GameMode, MangoHud).

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="packages-gaming"
# shellcheck disable=SC2034
MODULE_DESC="Gaming (Steam, GameMode, MangoHud, ProtonUp-Qt)"
# shellcheck disable=SC2034
MODULE_OPTIN=1
# shellcheck disable=SC2034
MODULE_DEPS="packages pacman-conf flatpak"

module_apply() {
  install_package_list gaming
}
