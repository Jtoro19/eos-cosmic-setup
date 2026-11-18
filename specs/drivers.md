# drivers

## Purpose

Install the CPU microcode and the GPU userspace drivers that match the
hardware, detected at run time. Nothing is hardcoded to one vendor.

## Source of truth

Captured from the reference host (AMD Ryzen CPU, AMD Radeon RX 7900 XTX plus
an AMD integrated GPU), where these are installed: `amd-ucode`, `mesa`,
`lib32-mesa`, `vulkan-radeon`, `lib32-vulkan-radeon`. There is no data file in
this repository; the package choice is encoded in `modules/10-drivers.sh`.

Findings checked on the host:

- `libva-mesa-driver` no longer exists as a package. It was merged into
  `mesa`, which now `Provides: libva-mesa-driver` (and `Replaces` the old
  one), so VA-API and VDPAU for AMD come with `mesa`. The module does not
  list it.
- `vulkan-icd-loader` is a hard dependency of `vulkan-radeon` and
  `vulkan-intel` (and `lib32-vulkan-icd-loader` of their lib32 variants), so
  the module never lists it. On this host it is installed as a dependency.
- `nvidia-inst` is in the EndeavourOS repo (`pacman -Si nvidia-inst`, depends
  on `expac`). It is not installed on the host.

## Files and packages touched

- No files are created or modified.
- Official packages, only the missing ones, through `ensure_packages`:
  - CPU: `amd-ucode` (AMD) or `intel-ucode` (Intel).
  - Always: `mesa`, plus `lib32-mesa` when multilib is enabled.
  - AMD GPU: `vulkan-radeon` (+ `lib32-vulkan-radeon`).
  - Intel GPU: `vulkan-intel`, `intel-media-driver` (+ `lib32-vulkan-intel`).
  - NVIDIA GPU: only `nvidia-inst` (see below).
- No services are enabled. Kernel parameters, dracut, mkinitcpio and the
  bootloader are not touched (the opt-in boot module owns those).

### Microcode and the initramfs

On EndeavourOS the initramfs is built by dracut through the pacman hooks
(`/usr/share/libalpm/hooks/90-dracut-install.hook`). Installing the microcode
package triggers those hooks on the next initramfs build, and dracut embeds the
microcode in the early cpio. On this host `/boot/amd-ucode.img` exists and
`/etc/dracut.conf.d/` holds only `eos-defaults.conf`, `eos_amd_amdgpu.conf` and
`resume.conf`; there is no ucode-specific dracut config, and the module adds
none. The new microcode is loaded after the next initramfs rebuild and reboot.

## Hardware detection

- CPU: `detect_cpu_vendor`. `amd` -> `amd-ucode`, `intel` -> `intel-ucode`,
  `unknown` -> `log_warn` and skip.
- GPU: `detect_gpu_vendors` (PCI IDs 1002 AMD, 8086 Intel, 10de NVIDIA). It may
  return several vendors (hybrid laptops); each adds its own packages.
- No match (VMs: virtio 1af4, QXL/bochs 1234, VMware 15ad, or no dedicated
  GPU): `mesa` plus `vulkan-swrast` (software Vulkan, so Vulkan apps still
  start; OpenGL comes from mesa's llvmpipe). The module logs "virtual GPU".
- Multilib: lib32 packages are installed only when `/etc/pacman.conf` has an
  uncommented `[multilib]` header. Otherwise the module warns and skips them.
  `pacman-conf` (05) runs before `drivers` (10) and enables multilib, so the
  lib32 packages install in the same run; the check is repeated every run.
- NVIDIA: package selection is delegated to `nvidia-inst`, which picks the
  driver series and DKMS or not. If any `nvidia*` package other than
  `nvidia-inst` is installed, nothing is done. Otherwise the module installs
  `nvidia-inst` (when it is in the repos) and warns the user to run
  `nvidia-inst` once. It is never run automatically: its help lists no
  `--yes`/`--noconfirm` flag, and it can prompt (for example for `--open` or
  `--nouveau` on some GPUs) and needs sudo. The flag list was read from the
  upstream script, not run. Nothing NVIDIA can be tested on the reference host;
  only the dry-run decision logic was exercised through the overrides below.
  The user's own notes say GTX 10xx and older need the legacy
  `nvidia-580xx-dkms` driver (AUR); whether `nvidia-inst` selects it on its
  own is unverified, so check the result on such a card.

### Test-only overrides

For simulating other hardware with `--dry-run` (never needed in normal use):

- `DRIVERS_CPU_VENDOR=amd|intel|unknown`
- `DRIVERS_GPU_VENDORS="amd intel nvidia"` (set to the empty string for a VM)
- `DRIVERS_MULTILIB=0|1`

## Idempotency check

All checks are read-only (`pacman -Qq`, `pacman -Si`, a grep of
`/etc/pacman.conf`). `ensure_packages` only installs missing packages, so a
second run reports "Nothing to change". On the reference host the first run
already reports 0 changes. Warnings (unknown CPU, no multilib, NVIDIA driver to
run by hand) are not counted as changes.

## Revert

- `sudo pacman -Rns <package>` for anything installed by the module. Removing
  `mesa` or the microcode is rarely wanted; `amd-ucode`/`intel-ucode` can be
  removed and the initramfs rebuilt.
- If `nvidia-inst` was run by hand, remove the nvidia packages it installed with
  `sudo pacman -Rns` (list them with `pacman -Qq | rg '^nvidia'`).

## Verification

- `./install.sh --only drivers --dry-run` prints "Nothing to change" after
  applying (and on the reference host).
- `pacman -Q amd-ucode mesa vulkan-radeon` (or the Intel equivalents) succeeds.
- `vulkaninfo --summary` (package `vulkan-tools`) lists the GPU.
- After a reboot, `journalctl -k | rg -i microcode` shows the updated revision.
