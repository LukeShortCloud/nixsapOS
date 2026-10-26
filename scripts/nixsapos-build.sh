# Where the image is written. The container commands in CONTRIBUTING.md mount it from ~/.cache/nixsapos on the host.
output_dir="${NIXSAPOS_OUTPUT_DIR:?Set NIXSAPOS_OUTPUT_DIR to a directory outside the repository. See CONTRIBUTING.md.}"
# A `path:` flake reference copies the whole repository into the Nix store, ignoring .gitignore, so an image inside it is copied too.
case "$(realpath --canonicalize-missing "${output_dir}")/" in
    "$(pwd -P)/"*)
        echo "NIXSAPOS_OUTPUT_DIR must be outside the repository: ${output_dir}" >&2
        exit 1
        ;;
esac
image="${output_dir}/${NIXSAPOS_IMAGE_NAME}.img"

# The installed system plus 25% for file system overhead. The root partition shrinks to fit at the end.
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
root_partition="${loop_device}p2"
# The device that holds the root file system: the partition, or the opened LUKS2 volume inside it.
root_device="${root_partition}"
# A name that can't clash with a LUKS2 volume on the build host.
root_mapper="nixsapos-build-$$"
# Install into a directory first. The root file system is created from it at the end.
root_dir="$(mktemp -d)"
chmod 755 "${root_dir}"
cleanup() {
    umount --recursive "${root_dir}/boot" || true
    if [[ -e "/dev/mapper/${root_mapper}" ]]; then
        systemd-cryptsetup detach "${root_mapper}" || true
    fi
    losetup --detach "${loop_device}" || true
    # NixOS makes /var/empty immutable.
    chattr -i "${root_dir}/var/empty" 2>/dev/null || true
    rm -rf --one-file-system "${root_dir}"
}
trap cleanup EXIT

# Mount the boot partition by partition instead of by label, in case the build host has a nixsapOS drive attached.
mkdir "${root_dir}/boot"
mount -o umask=0077 "${loop_device}p1" "${root_dir}/boot"

# The flake that the installed system rebuilds from.
mkdir "${root_dir}/etc"
cp --recursive --no-preserve=mode "${NIXSAPOS_HOST_FLAKE}" "${root_dir}/etc/nixos"

# Install the system the same way as on a real computer, including the bootloader.
nixos-install \
    --root "${root_dir}" \
    --system "${NIXSAPOS_TOPLEVEL}" \
    --no-root-passwd \
    --no-channel-copy
# ⚠️ Every flashed drive would share this boot loader random seed (see `bootctl --random-seed=no`).
# systemd-boot-random-seed.service creates a new one on the first boot.
rm "${root_dir}/boot/loader/random-seed"
umount "${root_dir}/boot"

if [[ "${NIXSAPOS_ROOT_ENCRYPT}" != "off" ]]; then
    # systemd-repart encrypted the root partition with an empty password. Mark it so the first boot asks for a new one.
    # `cryptsetup config` always sets both the label and the subsystem, so keep the label.
    cryptsetup config \
        --label "$(blkid --probe --match-tag LABEL --output value "${root_partition}")" \
        --subsystem "${NIXSAPOS_ROOT_EMPTY_PASSWORD_MARKER}" \
        "${root_partition}"
    # Open it the same way as the boot does.
    systemd-cryptsetup attach "${root_mapper}" "${root_partition}" - try-empty-password=yes,headless=yes
    root_device="/dev/mapper/${root_mapper}"
fi
# The space in front of the file system: the LUKS2 header, or nothing.
root_header_size="$(( $(blockdev --getsize64 "${root_partition}") - $(blockdev --getsize64 "${root_device}") ))"

# /home is its own Btrfs subvolume, so that Snapper can take snapshots of it without the system.
# Root stays the top-level subvolume, so /home needs no extra mount.
mkdir -p "${root_dir}/home"

# Create the smallest possible root file system from the installed files. The first boot grows it to fill the drive.
mkfs.btrfs \
    --force \
    --label "${NIXSAPOS_ROOT_LABEL}" \
    --compress "${NIXSAPOS_ROOT_COMPRESSION}" \
    --rootdir "${root_dir}" \
    --subvol rw:home \
    --shrink \
    "${root_device}"
root_fs_size="$(btrfs inspect-internal dump-super "${root_device}" | awk '$1 == "total_bytes" { print $2 }')"

cleanup
trap - EXIT

# Shrink the root partition to match, in whole MiB.
mib=1048576
root_sectors="$(( (root_header_size + root_fs_size + mib - 1) / mib * mib / 512 ))"
printf ',%s\n' "${root_sectors}" | sfdisk --quiet -N 2 "${image}"
# End the image 1 MiB after root, which leaves room for the backup partition table.
# Write the table again so that the backup table and the protective MBR match the new size.
root_start="$(partx -g -o START -n 2 "${image}" | tr -d ' ')"
partition_table="$(sfdisk --dump "${image}" | grep -v -E '^(first-lba|last-lba):')"
truncate -s "$(( (root_start + root_sectors) * 512 + mib ))" "${image}"
echo "${partition_table}" | sfdisk --quiet "${image}"

# Give the output to the owner of the repository instead of root. Docker creates a missing volume directory as root, so this includes the directory.
chown --recursive --reference=. "${output_dir}"
