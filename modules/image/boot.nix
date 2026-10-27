{ config, lib, ... }:

let
  limit = config.nixsapos.generations.limit;
in
{
  options.nixsapos.generations.limit = lib.mkOption {
    type = lib.types.ints.positive;
    default = 5;
    description = "How many NixOS generations to keep, including the current one.";
  };
  options.nixsapos.image.snapper.enable = lib.mkEnableOption ''
    monthly Snapper snapshots of /home/, keeping the last 5 similar to the 5 NixOS generations.
    /home/ must be a Btrfs subvolume, which is only true for drives flashed after it became one
  '';

  config = {
    # Mount by label so the same image works reliably on any drive.
    fileSystems."/" = {
      device = "/dev/disk/by-label/nixsapos-root";
      fsType = "btrfs";
      options = [
        # Let zstd try every write. Plain `compress` stops compressing a file when its first write does not shrink.
        "compress-force=zstd:2"
        "noatime"
        # Write to the drive every 5 minutes instead of every 30 seconds for fewer writes.
        # A power loss or an unplugged drive loses up to 5 minutes of changes.
        "commit=300"
      ];
    };
    fileSystems."/boot" = {
      device = "/dev/disk/by-label/NXS-EFI";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };
    # Use RAM for temporary files for fewer writes to the drive.
    boot.tmp.useTmpfs = true;
    # Keep logs in RAM for fewer writes to the drive. They are lost on reboot.
    # The secure image keeps them on the drive, like the winesapOS secure image.
    services.journald.storage = lib.mkIf (!config.nixsapos.image.encryption.enable) "volatile";
    fileSystems."/var/log" = lib.mkIf (!config.nixsapos.image.encryption.enable) {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [
        "mode=0755"
        "nosuid"
        "nodev"
      ];
    };
    # I/O schedulers for a responsive desktop: BFQ for SATA, SD card, and USB drives. Kyber for NVMe drives.
    services.udev.extraRules = ''
      ACTION=="add|change", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/scheduler}="bfq"
      ACTION=="add|change", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="kyber"
    '';
    boot.kernel.sysctl = {
      # Cache more writes in RAM for fewer writes to the drive.
      "vm.dirty_background_ratio" = 40;
      "vm.dirty_ratio" = 80;
      "vm.vfs_cache_pressure" = 50;
    };

    # Use systemd-boot instead of GRUB.
    boot.loader.systemd-boot.enable = true;
    # Make systemd-boot more portable.
    boot.loader.efi.canTouchEfiVariables = false;
    # The first-boot growth and the encryption run in the systemd initrd.
    boot.initrd.systemd.enable = true;

    # Load storage and input drivers in the initrd for any PC and include all redistributable firmware.
    hardware.enableAllHardware = true;
    # Load CPU microcode updates for both vendors. The kernel only loads the one that matches the CPU.
    hardware.cpu.amd.updateMicrocode = true;
    hardware.cpu.intel.updateMicrocode = true;
    boot.kernelParams = [
      # Never suspend USB devices, including the drive nixsapOS runs from.
      "usbcore.autosuspend=-1"
    ]
    # Turn off CPU vulnerability mitigations for more performance on the minimal image only.
    ++ lib.optional (!config.nixsapos.image.encryption.enable) "mitigations=off";

    # Rebuild from the flake in /etc/nixos.
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Keep only the newest boot entries, so the boot partition doesn't fill up with old kernels.
    # On every rebuild, the kernels and initrds that no remaining entry uses are deleted from it.
    boot.loader.systemd-boot.configurationLimit = limit;

    # Regularly delete older generations and garbage-collect the Nix store.
    programs.nh = {
      enable = true;
      clean = {
        enable = true;
        extraArgs = "--keep ${toString limit}";
      };
      # `nh os switch` rebuilds from the flake installed in the image.
      flake = "/etc/nixos";
    };

    # Backups of /home/. The system itself needs none, because NixOS generations replace root snapshots.
    services.snapper = lib.mkIf config.nixsapos.image.snapper.enable {
      # One snapshot a month instead of winesapOS's hourly ones that are mostly deleted again, for fewer writes to the drive.
      # A persistent timer catches up on a month when the drive was not plugged in.
      snapshotInterval = "monthly";
      persistentTimer = true;
      configs.home = {
        SUBVOLUME = "/home";
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = 0;
        TIMELINE_LIMIT_DAILY = 0;
        TIMELINE_LIMIT_WEEKLY = 0;
        # 5, the same number as the NixOS generations, so there is one number to remember (winesapOS keeps 6).
        TIMELINE_LIMIT_MONTHLY = 5;
        TIMELINE_LIMIT_QUARTERLY = 0;
        TIMELINE_LIMIT_YEARLY = 0;
      };
    };
    # Snapper stores the snapshots in a .snapshots subvolume, which the NixOS module does not create.
    # The tmpfiles "v" type creates a Btrfs subvolume if it does not exist yet.
    systemd.tmpfiles.rules = lib.mkIf config.nixsapos.image.snapper.enable [ "v /home/.snapshots 0750 root root -" ];
  };
}
