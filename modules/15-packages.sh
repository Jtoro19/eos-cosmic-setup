#!/usr/bin/env bash
# modules/15-packages.sh: Core everyday desktop and CLI packages (browsers, CLI tools, fonts, codecs).

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="packages"
# shellcheck disable=SC2034
MODULE_DESC="Core everyday desktop and CLI packages (browsers, CLI tools, fonts, codecs)"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS=""

module_apply() {
  install_package_list core
}
