#!/usr/bin/env bash
# Boot a nixsapOS image in a local QEMU virtual machine with UEFI firmware (OVMF).
# This is for local testing only. Building the image never uses a virtual machine.
#
# Usage: scripts/nixsapos-test-vm.sh [IMAGE]
#   IMAGE defaults to result/nixsapos.raw from `nix build .#image`.
# Environment variables:
#   NIXSAPOS_VM_DIR        Where the disk copy and UEFI variables are stored (default: vm/).
#   NIXSAPOS_VM_DISK_SIZE  Size of the virtual drive, to test growing the root partition (default: 32G).
#   NIXSAPOS_VM_MEMORY     RAM for the virtual machine (default: 4G).
#   NIXSAPOS_VM_HEADLESS   Set to 1 to use the serial console in the terminal instead of a window.

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="${1:-${repo_dir}/result/nixsapos.raw}"
vm_dir="${NIXSAPOS_VM_DIR:-${repo_dir}/vm}"
disk_size="${NIXSAPOS_VM_DISK_SIZE:-32G}"
memory="${NIXSAPOS_VM_MEMORY:-4G}"

# Use QEMU and OVMF from the nixpkgs version pinned in flake.lock.
nix_build() {
    nix --extra-experimental-features "nix-command flakes" build --no-link --print-out-paths \
        --inputs-from "path:${repo_dir}" "nixpkgs#$1"
}
qemu="$(nix_build qemu_kvm)"
ovmf="$(nix_build OVMF.fd)"

mkdir -p "${vm_dir}"
# Never boot the image itself because the first boot changes the drive.
cp --sparse=always "${image}" "${vm_dir}/disk.raw"
chmod u+w "${vm_dir}/disk.raw"
# Grow the copy, like flashing the image onto a bigger USB drive.
"${qemu}/bin/qemu-img" resize -f raw "${vm_dir}/disk.raw" "${disk_size}"
# Start with empty UEFI variables every time, like plugging the drive into a new PC.
cp "${ovmf}/FV/OVMF_VARS.fd" "${vm_dir}/vars.fd"
chmod u+w "${vm_dir}/vars.fd"

display_args=()
if [[ "${NIXSAPOS_VM_HEADLESS:-0}" == "1" ]]; then
    display_args=(-nographic)
fi

exec "${qemu}/bin/qemu-system-x86_64" \
    -machine q35 -enable-kvm -cpu host -smp 4 -m "${memory}" \
    -drive "if=pflash,format=raw,readonly=on,file=${ovmf}/FV/OVMF_CODE.fd" \
    -drive "if=pflash,format=raw,file=${vm_dir}/vars.fd" \
    -drive "if=virtio,format=raw,file=${vm_dir}/disk.raw" \
    -nic user,model=virtio-net-pci \
    "${display_args[@]}"
