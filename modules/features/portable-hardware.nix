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

    # Fingerprint readers. Users add a fingerprint in System Settings > Users. It then unlocks the screen and works with "sudo".
    services.fprintd.enable = true;
    # Only use a password for the login screen and the console. A fingerprint check there blocks typing the password until it times out.
    security.pam.services.login.fprintAuth = false;

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
      # Only NFSv4 network shares.
      nfs = true;
      ntfs = true;
      sshfs = true;
      xfs = true;
    };
    # NFS turns on rpcbind. That service listens on port 111 on every network. Disable it for security reasons to force NFSv4 instead.
    services.rpcbind.enable = lib.mkForce false;

    # Virtual machine guest tools. Each service only starts in its own hypervisor.

    # Hyper-V: the host can shut down the guest, read its IP address, and copy files into it.
    # Not virtualisation.hypervGuest, which loads the Hyper-V kernel modules in the initrd of every PC.
    # They load automatically on Hyper-V.
    systemd.packages = [ config.boot.kernelPackages.hyperv-daemons.lib ];
    systemd.targets.hyperv-daemons.wantedBy = [ "multi-user.target" ];

    # QEMU and KVM: the host can shut down the guest and read its IP address. SPICE shares the clipboard.
    services.qemuGuest.enable = true;
    services.spice-vdagentd.enable = true;
    systemd.services.spice-vdagentd.unitConfig.ConditionPathExists = "/dev/virtio-ports/com.redhat.spice.0";

    # VirtualBox: shared folders, the shared clipboard, and resizing the screen with the window.
    virtualisation.virtualbox.guest = {
      enable = true;
      # The kernel's own vboxguest and vboxsf modules. VirtualBox's modules often do not build for new kernels.
      use3rdPartyModules = false;
      # Only build the tools. The package also builds VirtualBox's modules, which would break the build for a new kernel.
      package = config.boot.kernelPackages.virtualboxGuestAdditions.overrideAttrs (old: {
        preBuild = (old.preBuild or "") + ''
          make() { :; }
        '';
        # No modules to list in depmod.d.
        preInstall = (old.preInstall or "") + ''
          shopt -s nullglob
        '';
      });
    };
    # Start it when the VirtualBox device appears. At boot, the service waits for that device before it checks for VirtualBox.
    # It would delay the boot of every other PC until the wait times out.
    systemd.services.virtualbox.wantedBy = lib.mkForce [ "dev-vboxguest.device" ];

    # VMware: shared folders, and the host can shut down the guest and read its IP address.
    # The shared clipboard and drag and drop need an X11 session.
    virtualisation.vmware.guest.enable = true;

    # Xen (XenServer and XCP-ng): the host can shut down the guest and read its IP address.
    # Xen hides the emulated disk from the guest. The initrd needs the Xen disk driver to find the root partition.
    boot.initrd.availableKernelModules = [ "xen-blkfront" ];
    services.xe-guest-utilities.enable = true;
    # Without it, both services start on every PC, and xe-daemon fails.
    systemd.services.xe-daemon.unitConfig.ConditionVirtualization = "xen";
    systemd.services.xe-linux-distribution.unitConfig.ConditionVirtualization = "xen";
  };
}
