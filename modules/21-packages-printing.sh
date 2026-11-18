#!/usr/bin/env bash
# modules/21-packages-printing.sh: Printing and scanning (CUPS, HPLIP, SANE, drivers).

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="packages-printing"
# shellcheck disable=SC2034
MODULE_DESC="Printing and scanning (CUPS, HPLIP, SANE, drivers)"
# shellcheck disable=SC2034
MODULE_OPTIN=1
# shellcheck disable=SC2034
MODULE_DEPS="packages"

module_apply() {
  install_package_list printing
}
