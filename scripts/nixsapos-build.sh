output_dir="output"
image="${output_dir}/nixsapos.img"

# The installed system plus 25% for file system overhead.
nar_size="$(cat "${NIXSAPOS_CLOSURE_INFO}/total-nar-size")"
root_size="$(( nar_size * 5 / 4 ))"
esp_size="$(numfmt --from=iec "${NIXSAPOS_ESP_SIZE}")"

mkdir -p "${output_dir}"
rm -f "${image}"
# Create the partition table and the labelled, formatted partitions.
systemd-repart \
    --empty=create \
    --size="$(( esp_size + root_size ))" \
    --definitions="${NIXSAPOS_PARTITIONS}" \
    --dry-run=no \
    "${image}"

loop_device="$(losetup --find --show --partscan "${image}")"
mount_dir="$(mktemp -d)"
cleanup() {
    umount --recursive "${mount_dir}" || true
    losetup --detach "${loop_device}" || true
    rmdir "${mount_dir}" || true
}
trap cleanup EXIT

# Mount by partition instead of by label, in case the build host has a nixsapOS drive attached.
mount -o compress=zstd:2,noatime "${loop_device}p2" "${mount_dir}"
mkdir "${mount_dir}/boot"
mount -o umask=0077 "${loop_device}p1" "${mount_dir}/boot"

# The flake that the installed system rebuilds from.
mkdir -p "${mount_dir}/etc"
cp --recursive --no-preserve=mode "${NIXSAPOS_HOST_FLAKE}" "${mount_dir}/etc/nixos"

# Install the system the same way as on a real computer, including the bootloader.
nixos-install \
    --root "${mount_dir}" \
    --system "${NIXSAPOS_TOPLEVEL}" \
    --no-root-passwd \
    --no-channel-copy
# ⚠️ Every flashed drive would share this boot loader random seed (see `bootctl --random-seed=no`).
# systemd-boot-random-seed.service creates a new one on the first boot.
rm "${mount_dir}/boot/loader/random-seed"

cleanup
trap - EXIT

# Give the output to the owner of the repository instead of root.
chown --recursive --reference=. "${output_dir}"
