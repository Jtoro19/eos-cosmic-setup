#!/usr/bin/env bash
# modules/22-packages-ai.sh: Ollama built for the detected GPU vendor.

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="packages-ai"
# shellcheck disable=SC2034
MODULE_DESC="Local AI: Ollama build chosen by GPU vendor (ROCm, CUDA or CPU)"
# shellcheck disable=SC2034
MODULE_OPTIN=1
# shellcheck disable=SC2034
MODULE_DEPS="packages"

# _ai_gpu_vendors: space-separated amd/intel/nvidia, possibly empty.
# PACKAGES_AI_GPU_VENDORS is a test-only override (set, even empty, replaces
# detection).
_ai_gpu_vendors() {
  if [[ -n "${PACKAGES_AI_GPU_VENDORS+x}" ]]; then
    printf '%s\n' "$PACKAGES_AI_GPU_VENDORS"
  else
    detect_gpu_vendors
  fi
}

# _ai_ollama_package: amd -> ollama-rocm, nvidia -> ollama-cuda, else ollama.
_ai_ollama_package() {
  local vendors v
  vendors="$(_ai_gpu_vendors)"
  for v in $vendors; do
    if [[ "$v" == "amd" ]]; then
      printf 'ollama-rocm\n'
      return 0
    fi
  done
  for v in $vendors; do
    if [[ "$v" == "nvidia" ]]; then
      printf 'ollama-cuda\n'
      return 0
    fi
  done
  printf 'ollama\n'
}

module_apply() {
  # ollama-rocm and ollama-cuda depend on the base ollama package, so they are
  # add-ons, not replacements: installing one pulls ollama in.
  ensure_packages "$(_ai_ollama_package)"
}
