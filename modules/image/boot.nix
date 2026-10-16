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

  config = {
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
    # Never suspend USB devices, including the drive nixsapOS runs from.
    boot.kernelParams = [ "usbcore.autosuspend=-1" ];

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
  };
}
