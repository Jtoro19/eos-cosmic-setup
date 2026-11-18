#!/usr/bin/env bash
# modules/16-packages-dev.sh: Development tools (git, Rust, Go, Python, Docker, VS Code, Claude Code).

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="packages-dev"
# shellcheck disable=SC2034
MODULE_DESC="Development tools (git, Rust, Go, Python, Docker, VS Code, Claude Code)"
# shellcheck disable=SC2034
MODULE_OPTIN=1
# shellcheck disable=SC2034
MODULE_DEPS="packages"

module_apply() {
  install_package_list dev
}
