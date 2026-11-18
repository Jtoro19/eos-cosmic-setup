#!/usr/bin/env bash
# modules/80-kvm.sh: KVM/QEMU virtualization with libvirt and virt-manager.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="kvm"
# shellcheck disable=SC2034
MODULE_DESC="KVM/QEMU virtualization: libvirt, virt-manager, UEFI and TPM, default NAT network"
# shellcheck disable=SC2034
MODULE_OPTIN=1
# shellcheck disable=SC2034
MODULE_DEPS=""

_KVM_PACKAGES=(qemu-desktop libvirt virt-manager virt-viewer dnsmasq edk2-ovmf swtpm)
_KVM_URI="qemu:///system"

# _kvm_has_virtualization: true when the CPU advertises AMD-V or VT-x.
_kvm_has_virtualization() {
  grep -qE '^flags.*\b(svm|vmx)\b' /proc/cpuinfo 2>/dev/null
}

# _kvm_prepare_iptables: on systems that still carry the old iptables package
# without iptables-nft, libvirt's dependencies conflict with it. pacman
# answers that prompt "no" under --noconfirm, so the install would abort.
# --ask 4 is the ALPM_QUESTION_CONFLICT_PKG bit (alpm.h): it answers yes to
# "remove the conflicting package?" for this one transaction only.
# Current iptables packages already provide iptables-nft: nothing to do then.
_kvm_prepare_iptables() {
  local pkg missing=0
  for pkg in "${_KVM_PACKAGES[@]}"; do
    pkg_installed "$pkg" || missing=1
  done
  ((missing)) || return 0
  if pkg_installed iptables && ! pkg_installed iptables-nft; then
    log_change "replace legacy iptables with iptables-nft"
    run_sudo pacman -S --needed --noconfirm --ask 4 iptables-nft
  fi
}

# _kvm_net_info: print `virsh net-info default`. Read-only; tries without
# sudo first (works for members of the libvirt group). Prints nothing and
# returns 1 when the state cannot be read. A missing network prints
# "undefined" and returns 0.
_kvm_net_info() {
  local out err tries=1 i
  command -v virsh >/dev/null 2>&1 || return 1
  # After a real start the daemon may need a moment to accept connections.
  [[ "$DRY_RUN" == "1" ]] || tries=5
  for ((i = 0; i < tries; i++)); do
    if out="$(virsh -c "$_KVM_URI" net-info default 2>&1)"; then
      printf '%s\n' "$out"
      return 0
    fi
    err="$out"
    if [[ "$DRY_RUN" != "1" ]]; then
      # Fresh install: the user is not in the libvirt group in this session.
      if out="$(sudo -n virsh -c "$_KVM_URI" net-info default 2>&1)"; then
        printf '%s\n' "$out"
        return 0
      fi
      err="$out"
    fi
    if [[ "$err" == *"Network not found"* ]]; then
      printf 'undefined\n'
      return 0
    fi
    sleep 1
  done
  return 1
}

# _kvm_net_start: start the default network. When libvirt cannot find its
# firewalld zone (firewalld was running before libvirt was installed), restart
# firewalld and libvirtd and retry once.
_kvm_net_start() {
  local err
  if [[ "$DRY_RUN" == "1" ]]; then
    run_sudo virsh -c "$_KVM_URI" net-start default
    return 0
  fi
  if err="$(sudo -n virsh -c "$_KVM_URI" net-start default 2>&1)"; then
    return 0
  fi
  if [[ "$err" == *"libvirt"*"zone"* || "$err" == *"zone"*"libvirt"* ]]; then
    log_warn "firewalld has no 'libvirt' zone yet; restarting firewalld and libvirtd, then retrying"
    # Best effort: the retry below decides whether the network came up.
    run_sudo_may_fail systemctl restart firewalld || true
    run_sudo_may_fail systemctl restart libvirtd || true
    if sudo -n virsh -c "$_KVM_URI" net-start default; then
      return 0
    fi
  else
    log_warn "net-start default failed: $err"
  fi
  log_warn "default network did not start; see reference/kvm-setup-cosmic.md section 4 (firewall_backend = \"nftables\" in /etc/libvirt/network.conf). Not changed automatically."
  return 0
}

# _kvm_default_network: make sure the default NAT network exists, autostarts
# and is active. Unknown state counts as "needs action".
_kvm_default_network() {
  local info="" known=1 active="no" autostart="no"
  info="$(_kvm_net_info)" || known=0

  if [[ "$info" == "undefined" ]]; then
    local xml=/etc/libvirt/qemu/networks/default.xml
    if [[ -f "$xml" ]]; then
      log_change "define libvirt default network"
      run_sudo virsh -c "$_KVM_URI" net-define "$xml"
    else
      log_warn "libvirt default network is not defined and $xml is missing; skipping"
      return 0
    fi
  elif ((known)); then
    active="$(awk '$1 == "Active:" { print $2 }' <<<"$info")"
    autostart="$(awk '$1 == "Autostart:" { print $2 }' <<<"$info")"
  fi

  if [[ "$autostart" != "yes" ]]; then
    log_change "enable autostart of libvirt default network"
    run_sudo virsh -c "$_KVM_URI" net-autostart default
  fi
  if [[ "$active" != "yes" ]]; then
    log_change "start libvirt default network"
    _kvm_net_start
  fi
}

module_apply() {
  if ! _kvm_has_virtualization; then
    log_warn "CPU virtualization (SVM/VT-x) not found; enable it in the firmware setup. Skipping kvm."
    return 0
  fi

  _kvm_prepare_iptables
  ensure_packages "${_KVM_PACKAGES[@]}" || return 1

  ensure_system_unit_enabled libvirtd.service
  ensure_user_in_group libvirt
  ensure_user_in_group kvm

  _kvm_default_network
  return 0
}
