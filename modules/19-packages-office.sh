#!/usr/bin/env bash
# modules/19-packages-office.sh: Office and productivity (LibreOffice, Obsidian).

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="packages-office"
# shellcheck disable=SC2034
MODULE_DESC="Office and productivity (LibreOffice, Obsidian)"
# shellcheck disable=SC2034
MODULE_OPTIN=1
# shellcheck disable=SC2034
MODULE_DEPS="packages"

module_apply() {
  install_package_list office
}
