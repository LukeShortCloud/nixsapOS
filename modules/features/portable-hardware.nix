{ config, lib, ... }:

let
  cfg = config.nixsapos.portableHardware;
in
{
  options.nixsapos.portableHardware.enable = lib.mkEnableOption "drivers and firmware for booting on any PC";

  config = lib.mkIf cfg.enable {
    # Bluetooth with the adapter powered on at boot. Plasma adds its Bluetooth settings and applet when this is on.
    hardware.bluetooth.enable = true;

    # Use drives and network shares from other computers. These are the NixOS file system modules that work with the latest kernel.
    # Their tools are installed, but nothing is added to the initrd because nixsapOS does not boot from them.
    # Not included: APFS (its module does not build for the latest kernel), GlusterFS (no NixOS file system module), and ZFS (needs an LTS kernel).
    boot.supportedFilesystems = {
      # An out-of-tree kernel module since Linux 6.17.
      bcachefs = true;
      # SMB (Windows) network shares.
      cifs = true;
      erofs = true;
      f2fs = true;
      jfs = true;
      # This also starts rpcbind, which NFS needs. The firewall blocks its port from other computers.
      nfs = true;
      ntfs = true;
      sshfs = true;
      xfs = true;
    };
  };
}
