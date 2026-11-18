#!/usr/bin/env bash
# modules/10-drivers.sh: CPU microcode and GPU userspace drivers, by detected vendor.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="drivers"
# shellcheck disable=SC2034
MODULE_DESC="CPU microcode and GPU drivers (mesa, Vulkan, VA-API) chosen by detected vendor"
# shellcheck disable=SC2034
MODULE_OPTIN=0
# shellcheck disable=SC2034
MODULE_DEPS=""

# _drivers_cpu_vendor: amd, intel or unknown. DRIVERS_CPU_VENDOR is a test-only
# override so other hardware can be simulated with --dry-run.
_drivers_cpu_vendor() {
  if [[ -n "${DRIVERS_CPU_VENDOR:-}" ]]; then
    printf '%s\n' "$DRIVERS_CPU_VENDOR"
  else
    detect_cpu_vendor
  fi
}

# _drivers_gpu_vendors: space-separated amd/intel/nvidia, possibly empty.
# DRIVERS_GPU_VENDORS is a test-only override; when set (even to the empty
# string) it replaces detection, so an empty value simulates a VM.
_drivers_gpu_vendors() {
  if [[ -n "${DRIVERS_GPU_VENDORS+x}" ]]; then
    printf '%s\n' "$DRIVERS_GPU_VENDORS"
  else
    detect_gpu_vendors
  fi
}

# _drivers_multilib_enabled: true when [multilib] is an active section in
# pacman.conf. DRIVERS_MULTILIB=0|1 is a test-only override.
_drivers_multilib_enabled() {
  if [[ -n "${DRIVERS_MULTILIB:-}" ]]; then
    [[ "$DRIVERS_MULTILIB" == "1" ]]
    return
  fi
  grep -Eq '^[[:space:]]*\[multilib\][[:space:]]*$' /etc/pacman.conf 2>/dev/null
}

# _drivers_microcode: install the microcode package matching the CPU. The
# initramfs hooks pick it up on their next run; no boot config is touched.
_drivers_microcode() {
  local cpu
  cpu="$(_drivers_cpu_vendor)"
  case "$cpu" in
    amd) ensure_packages amd-ucode ;;
    intel) ensure_packages intel-ucode ;;
    *) log_warn "unknown CPU vendor; skipping microcode" ;;
  esac
}

# _drivers_nvidia: delegate package selection to the EndeavourOS installer.
# nvidia-inst has no documented non-interactive flag, so it is never run
# automatically: install it and tell the user to run it once.
_drivers_nvidia() {
  local -a have=()
  mapfile -t have < <(pacman -Qq 2>/dev/null | grep -E '^nvidia' | grep -Ev '^nvidia-inst$' || true)
  if ((${#have[@]} > 0)); then
    log_info "NVIDIA packages already installed (${have[0]} ...); leaving them alone"
    return 0
  fi
  if ! pacman -Qq nvidia-inst >/dev/null 2>&1 && ! pacman -Si nvidia-inst >/dev/null 2>&1; then
    log_warn "NVIDIA GPU found but nvidia-inst is not available in the repos; install the NVIDIA driver manually"
    return 0
  fi
  ensure_packages nvidia-inst
  log_warn "NVIDIA GPU found but no NVIDIA driver installed: run 'nvidia-inst' once from a terminal (it picks the right driver series and may prompt)"
}

# _drivers_gpu: userspace drivers per GPU vendor.
_drivers_gpu() {
  local multilib="$1" vendors v
  local -a pkgs=(mesa)
  local -a pkgs32=(lib32-mesa)
  local nvidia=0 known=0
  vendors="$(_drivers_gpu_vendors)"

  for v in $vendors; do
    case "$v" in
      amd)
        known=1
        pkgs+=(vulkan-radeon)
        pkgs32+=(lib32-vulkan-radeon)
        ;;
      intel)
        known=1
        pkgs+=(vulkan-intel intel-media-driver)
        pkgs32+=(lib32-vulkan-intel)
        ;;
      nvidia)
        known=1
        nvidia=1
        ;;
      *) log_warn "ignoring unknown GPU vendor: $v" ;;
    esac
  done

  if ((!known)); then
    log_info "no AMD/Intel/NVIDIA GPU detected (virtual GPU?); installing mesa only"
  fi

  # vulkan-icd-loader is a hard dependency of vulkan-radeon and vulkan-intel
  # (and their lib32 variants), so it is never listed here.
  ensure_packages "${pkgs[@]}"
  if ((multilib)); then
    ensure_packages "${pkgs32[@]}"
  else
    log_warn "[multilib] is not enabled in /etc/pacman.conf; skipping lib32 drivers (${pkgs32[*]}). Enable it and re-run."
  fi

  if ((nvidia)); then
    _drivers_nvidia
  fi
}

module_apply() {
  local multilib=0
  if _drivers_multilib_enabled; then
    multilib=1
  fi

  _drivers_microcode
  _drivers_gpu "$multilib"
}
