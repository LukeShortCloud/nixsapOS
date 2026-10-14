{ config, lib, ... }:

let
  cfg = config.nixsapos.image.encryption;
  # The drive that systemd-boot started from.
  bootDisk = "/dev/disk/nixsapos-boot-disk";
in
{
  options.nixsapos.image.encryption.enable = lib.mkEnableOption "LUKS2 encryption of the root partition";

  config = lib.mkIf cfg.enable {
    # The build encrypts root with an empty password. repart labels the LUKS2 header "luks-nixsapos-root".
    # The Btrfs file system inside keeps the "nixsapos-root" label, so the root mount stays the same.
    nixsapos.image.partitions."20-root".Encrypt = "key-file";

    boot.initrd.luks.devices.nixsapos-root = {
      device = "/dev/disk/by-label/luks-nixsapos-root";
      # Unlock without asking while the password is still empty.
      tryEmptyPassphrase = true;
    };

    # Grow the root partition before it is unlocked, so the unlocked volume already fills it.
    # Growing it afterwards would need the volume key again to resize the volume (systemd-growfs fails with "Operation not permitted").
    # systemd-repart can only find the drive by itself after root is mounted, so give it the drive.
    # udev marks the drive with the partition that systemd-boot started from (ID_PART_GPT_AUTO_ROOT_DISK).
    boot.initrd.services.udev.rules = ''
      SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_PART_GPT_AUTO_ROOT_DISK}=="1", SYMLINK+="${lib.removePrefix "/dev/" bootDisk}"
    '';
    boot.initrd.systemd.repart.device = bootDisk;
    boot.initrd.systemd.services.systemd-repart.before = [ "systemd-cryptsetup@nixsapos\\x2droot.service" ];
  };
}
