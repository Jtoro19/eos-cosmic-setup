#!/usr/bin/env bash
# modules/23-packages-vmware.sh: VMware Workstation (AUR).

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="packages-vmware"
# shellcheck disable=SC2034
MODULE_DESC="VMware Workstation (AUR)"
# shellcheck disable=SC2034
MODULE_OPTIN=1
# shellcheck disable=SC2034
MODULE_DEPS="packages"

module_apply() {
  install_package_list vmware
}
