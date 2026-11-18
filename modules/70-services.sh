#!/usr/bin/env bash
# modules/70-services.sh: enable system services for what is installed.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="services"
# shellcheck disable=SC2034
MODULE_DESC="system services and groups for installed packages (network, bluetooth, cups, docker...)"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS=""

# Desktop services: enabled when their unit file exists.
_SERVICES_BASE=(
  NetworkManager.service
  bluetooth.service
  firewalld.service
  power-profiles-daemon.service
  systemd-timesyncd.service
  fstrim.timer
  avahi-daemon.service
)

# Services that come with an optional package group.
_SERVICES_OPTIONAL=(
  cups.service          # packages-printing
  docker.service        # packages-dev
  vmware-networks.service      # packages-vmware
  vmware-usbarbitrator.service # packages-vmware
)

module_apply() {
  local unit

  # This module only enables; it never disables or stops anything.
  for unit in "${_SERVICES_BASE[@]}" "${_SERVICES_OPTIONAL[@]}"; do
    ensure_system_unit_enabled "$unit"
  done

  # MariaDB needs its data directory initialized before the first start.
  if system_unit_exists mariadb.service &&
    ! systemctl is-enabled --quiet mariadb.service >/dev/null 2>&1; then
    log_change "initialize MariaDB data directory if empty"
    run_sudo sh -c '[ -d /var/lib/mysql/mysql ] || mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql'
  fi
  ensure_system_unit_enabled mariadb.service

  # SSH server only on request: exposing sshd is a per-machine decision.
  if [[ "${SERVICES_SSHD:-0}" == "1" ]]; then
    ensure_system_unit_enabled sshd.service
  fi

  # Groups for installed tools (only if the group exists).
  pkg_installed docker && ensure_user_in_group docker
  ensure_user_in_group adbusers
  return 0
}
