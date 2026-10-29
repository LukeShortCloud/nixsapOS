{ config, lib, pkgs, ... }:

let
  cfg = config.nixsapos.portableHardware;
in
{
  options.nixsapos.portableHardware.enable = lib.mkEnableOption "drivers and firmware for booting on any PC";

  config = lib.mkIf cfg.enable {
    # Bluetooth with the adapter powered on at boot. Plasma adds its Bluetooth settings and applet when this is on.
    hardware.bluetooth.enable = true;

    # iPhone and iPad support: files in Dolphin, USB tethering, and the "idevice*" command line tools.
    # usbmuxd talks to the device over USB. Plasma's kio-extras already uses it to show the device in Dolphin.
    services.usbmuxd.enable = true;
    environment.systemPackages = [ pkgs.libimobiledevice ];

    # "tlp-pd" lets Plasma's battery applet switch between the power profiles. It replaces power-profiles-daemon.
    # Its profiles use TLP's settings: performance = "_AC", balanced = "_BAT", and power saver = "_SAV".
    services.power-profiles-daemon.enable = false;
    services.tlp = {
      enable = true;
      pd.enable = true;
      settings = {
        PLATFORM_PROFILE_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_BOOST_ON_AC = 1;

        PLATFORM_PROFILE_ON_BAT = "balanced";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_performance";
        CPU_BOOST_ON_BAT = 0;

        DEVICES_TO_ENABLE_ON_STARTUP = "wifi";
        USB_AUTOSUSPEND = 0;
      };
    };

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
