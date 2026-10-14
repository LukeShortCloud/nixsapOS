{ pkgs, ... }:

let
  # exFAT labels can be at most 11 characters.
  label = "nos-drive";
in
{
  # A 16 GiB exFAT partition at the end of the drive for storage that Linux, macOS and Windows can access.
  # It is only created on first boot (not in the initial raw image).
  # systemd-repart places it after the root partition, which grows into the rest of the drive.
  systemd.repart.partitions."30-drive" = {
    # Set the partition type to Microsoft Basic Data (msftdata) so macOS and Windows can mount it.
    Type = "EBD0A0A2-B9E5-4433-87C0-68B6B72699C7";
    # The GPT partition name. The file system label is set when it is formatted below.
    Label = label;
    SizeMinBytes = "16G";
    SizeMaxBytes = "16G";
    # Skip this partition, instead of failing, when the drive is too small for it.
    # A lower priority is kept first and the root partition has the default of 0.
    Priority = 1;
  };

  # exFAT tools such as mkfs.exfat and fsck.exfat.
  boot.supportedFilesystems.exfat = true;

  # Format the partition after systemd-repart created it.
  # The repart `Format=exfat` setting fails because it sets an extended attribute that exFAT does not support.
  # It also would not set the file system label.
  systemd.services.nixsapos-drive-format = {
    description = "Format the exFAT drive partition";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig.Type = "oneshot";
    path = [ pkgs.exfatprogs pkgs.gawk pkgs.util-linux ];
    script = ''
      # Only look at the drive that the root file system is on, not other attached drives.
      root_device="$(findmnt --noheadings --nofsroot --output SOURCE --target /)"
      # Walk up from the root device to its disk, also through LUKS2 (nixsapos.image.encryption).
      root_disk="$(lsblk --inverse --list --noheadings --paths --output NAME,TYPE "$root_device" | awk '$2 == "disk" { print $1 }')"
      drive_partition="$(lsblk --list --noheadings --paths --output NAME,PARTLABEL "$root_disk" | awk '$2 == "${label}" { print $1 }')"
      if [ -z "$drive_partition" ]; then
        echo "There is no ${label} partition."
        exit 0
      fi
      # Never format a partition that already has a file system.
      # Only check the TYPE because probing also prints the partition entry.
      if [ -n "$(blkid --probe --match-tag TYPE --output value "$drive_partition")" ]; then
        echo "$drive_partition already has a file system."
        exit 0
      fi
      mkfs.exfat --volume-label "${label}" "$drive_partition"
    '';
  };
}
