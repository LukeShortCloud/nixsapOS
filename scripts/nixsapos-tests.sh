#!/usr/bin/env bash
# Check a booted nixsapOS machine.
# It only checks what shows at runtime. `nix flake check` already checks the configuration itself.
#
# Usage: sudo scripts/nixsapos-tests.sh
#   Or from another computer: go-task test HOST=nixsap@<IP_ADDRESS>
# It prints one PASS or FAIL line per check. The exit code is the number of failed checks (0 when all passed).

set -uo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this script as root (sudo)."
    exit 1
fi

failures=0
pass() {
    echo "PASS: $1"
}
fail() {
    echo "FAIL: $1"
    failures=$((failures + 1))
}
# Usage: check "description" command [arguments...]
check() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        pass "${description}"
    else
        fail "${description}"
    fi
}
# Usage: check_equal "description" "value" "expected value"
check_equal() {
    if [[ "$2" == "$3" ]]; then
        pass "$1"
    else
        fail "$1 (expected \"$3\", got \"$2\")"
    fi
}

# The block device that root is mounted from: the Btrfs partition, or the opened LUKS2 device on the secure image.
root_source="$(findmnt --noheadings --nofsroot --output SOURCE /)"
root_partition="$(readlink -f /dev/disk/by-partlabel/nixsapos-root)"
root_disk="/dev/$(lsblk --noheadings --nodeps --output PKNAME "${root_partition}")"
secure=false
if [[ "$(lsblk --noheadings --nodeps --output TYPE "${root_source}")" == "crypt" ]]; then
    secure=true
fi
cmdline="$(cat /proc/cmdline)"

echo "Testing nixsapOS on ${root_disk} (secure image: ${secure})..."

echo "Testing the boot..."
check "UEFI boot" test -d /sys/firmware/efi
check "systemd-boot" grep -q "Product: systemd-boot" <<< "$(bootctl status 2>/dev/null)"
check "USB autosuspend is off" grep -q "usbcore.autosuspend=-1" <<< "${cmdline}"
check_equal "no failed system services" "$(systemctl --failed --no-legend --plain | awk '{ print $1 }' | xargs)" ""
check "the display manager is running" systemctl is-active --quiet display-manager.service

echo "Testing the drive..."
check_equal "root is Btrfs" "$(findmnt --noheadings --output FSTYPE /)" "btrfs"
check_equal "root has the nixsapos-root label" "$(findmnt --noheadings --output LABEL /)" "nixsapos-root"
root_options="$(findmnt --noheadings --output OPTIONS / | tr ',' '\n')"
for option in compress-force=zstd:2 noatime commit=300; do
    check "root is mounted with ${option}" grep -qx "${option}" <<< "${root_options}"
done
# The first inode of every Btrfs subvolume is 256.
check_equal "/home is a Btrfs subvolume" "$(stat --format=%i /home)" "256"
check_equal "/boot is the NXS-EFI partition" "$(findmnt --noheadings --output LABEL /boot)" "NXS-EFI"
check "the nos-drive partition is exFAT" grep -qE "^nos-drive +exfat$" <<< "$(lsblk --noheadings --list --output PARTLABEL,FSTYPE "${root_disk}")"
# The image has all-zero partition UUIDs. The first boot gives every partition a new one.
check "every partition has a new UUID" test -z "$(lsblk --noheadings --list --output PARTUUID "${root_disk}" | grep -x "00000000-0000-0000-0000-000000000000")"
# Partitions and the GPT itself leave less than 1 GiB of the drive unused.
disk_size="$(lsblk --noheadings --nodeps --bytes --output SIZE "${root_disk}")"
partitions_size="$(lsblk --noheadings --list --bytes --output SIZE,TYPE "${root_disk}" | awk '$2 == "part" { sum += $1 } END { print sum }')"
check "the partitions fill the drive" test "$((disk_size - partitions_size))" -lt "$((1024 * 1024 * 1024))"
root_device_size="$(lsblk --noheadings --nodeps --bytes --output SIZE "${root_source}")"
root_fs_size="$(findmnt --noheadings --bytes --output SIZE /)"
check "Btrfs fills the root partition" test "$((root_fs_size * 100 / root_device_size))" -ge 95
check_equal "/tmp is in RAM" "$(findmnt --noheadings --output FSTYPE /tmp)" "tmpfs"
check "zram swap is on" grep -q zram <<< "$(swapon --show=NAME --noheadings)"
for queue in /sys/block/sd*/queue/scheduler /sys/block/mmcblk*/queue/scheduler /sys/block/nvme*/queue/scheduler; do
    [[ -e "${queue}" ]] || continue
    device="$(basename "$(dirname "$(dirname "${queue}")")")"
    scheduler=bfq
    [[ "${device}" == nvme* ]] && scheduler=kyber
    check "${device} uses the ${scheduler} I/O scheduler" grep -q "\[${scheduler}\]" "${queue}"
done

echo "Testing the services..."
check_equal "the fwupd refresh timer is masked" "$(systemctl is-enabled fwupd-refresh.timer)" "masked"
check_equal "nothing listens on the rpcbind port (111)" "$(ss --listening --tcp --udp --numeric --no-header "sport = :111")" ""
if [[ "$(systemctl is-enabled automatic-timezoned.service 2>/dev/null)" == "enabled" ]]; then
    check "the automatic time zone service is running" systemctl is-active --quiet automatic-timezoned.service
fi
check "the Flathub remote exists" grep -qx flathub <<< "$(flatpak remotes --system --columns=name)"
# Only the "unfree" gaming applications install RetroDECK. The install script lists the Flatpaks to install.
# It downloads several GB after the first boot. Wait for it to finish first.
flatpak_install_script="$(systemctl show --property=ExecStart --value flatpak-managed-install.service | grep -o "/nix/store/[^ ;]*" | head -n 1)"
if [[ -n "${flatpak_install_script}" ]] && grep -q net.retrodeck.retrodeck "${flatpak_install_script}"; then
    check_equal "the Flatpak install service finished" "$(systemctl show --property=ActiveState --value flatpak-managed-install.service)/$(systemctl show --property=Result --value flatpak-managed-install.service)" "inactive/success"
    check "RetroDECK is installed from Flathub" grep -qx flathub <<< "$(flatpak info --system --show-origin net.retrodeck.retrodeck 2>/dev/null)"
fi

echo "Testing /etc/nixos..."
for file in configuration.nix flake.lock flake.nix; do
    check "/etc/nixos/${file} exists" test -f "/etc/nixos/${file}"
done
# This also proves that the drive has every flake input that it needs to rebuild without a network.
build_dir="$(mktemp --directory)"
(cd "${build_dir}" && nixos-rebuild build --offline --flake /etc/nixos >/dev/null 2>&1)
check_equal "an offline rebuild builds the running system" "$(readlink -f "${build_dir}/result")" "$(readlink -f /run/current-system)"
rm -rf "${build_dir}"

if [[ "${secure}" == "true" ]]; then
    echo "Testing the secure image..."
    check "CPU vulnerability mitigations are on" test -z "$(grep -o "mitigations=off" <<< "${cmdline}")"
    check "logs are kept on the drive" test -d /var/log/journal
    check "the firewall is running" systemctl is-active --quiet firewalld.service
    check "AppArmor is running" systemctl is-active --quiet apparmor.service
    check "sudo asks for a password" test -z "$(grep -E "^%wheel.*NOPASSWD" /etc/sudoers)"
    check "KWallet is on" test ! -e /etc/xdg/kwalletrc
else
    echo "Testing the minimal image..."
    check "CPU vulnerability mitigations are off" grep -q "mitigations=off" <<< "${cmdline}"
    check_equal "logs are kept in RAM" "$(findmnt --noheadings --output FSTYPE /var/log)" "tmpfs"
    check "the journal is not on the drive" test ! -e /var/log/journal
    check_equal "there is no firewall" "$(systemctl is-active firewalld.service firewall.service | xargs)" "inactive inactive"
    check "sudo needs no password" grep -qE "^%wheel.*NOPASSWD" /etc/sudoers
    check "KWallet is off" grep -qx "Enabled=false" /etc/xdg/kwalletrc
fi

if [[ "${failures}" -gt 0 ]]; then
    echo "${failures} check(s) failed."
else
    echo "All checks passed."
fi
# Exit codes stop at 255.
exit "$((failures > 255 ? 255 : failures))"
