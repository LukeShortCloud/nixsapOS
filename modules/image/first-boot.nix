{ config, ... }:

{
  # Grow the root partition to fill the drive, using the same partition definitions as the image build.
  # systemd-repart runs in the initrd on every boot, but only changes something when the drive has free space.
  boot.initrd.systemd.repart.enable = true;
  systemd.repart.partitions = config.nixsapos.image.partitions;
  # Then grow the Btrfs file system to fill the partition.
  fileSystems."/".autoResize = true;
}
