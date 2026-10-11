{ ... }:

{
  # Mount by label so the same image works reliably on any drive.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixsapos-root";
    fsType = "btrfs";
    options = [
      "compress=zstd:2"
      "noatime"
    ];
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NXS-EFI";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };
  # Use RAM for temporary files for fewer writes to the drive.
  boot.tmp.useTmpfs = true;

  # Use systemd-boot instead of GRUB.
  boot.loader.systemd-boot.enable = true;
  # Make systemd-boot more portable.
  boot.loader.efi.canTouchEfiVariables = false;
}
