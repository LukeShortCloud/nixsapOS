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

# Give the output to the owner of the repository instead of root.
chown --recursive --reference=. "${output_dir}"
