{ config, lib, modulesPath, ... }:

let
  # A repart.d(5) setting value. For example: "esp", 512, true, or a list for repeated settings.
  repartValue = with lib.types; oneOf [ str int bool (listOf str) ];
in
{
  # Build the image with systemd-repart. It runs as a normal Nix build without a virtual machine.
  imports = [ "${modulesPath}/image/repart.nix" ];

  # Partition definitions shared by the image build (image.repart) and the first boot (systemd.repart).
  options.nixsapos.image.partitions = lib.mkOption {
    # Partition name -> repart setting name -> value.
    type = lib.types.attrsOf (lib.types.attrsOf repartValue);
    default = { };
    description = "systemd-repart settings for each partition, in the format of repart.d(5).";
  };

  config = {
    nixsapos.image.partitions = {
      "10-esp" = {
        Type = "esp";
        Format = "vfat";
        Label = "NXS-EFI";
        SizeMinBytes = "512M";
        SizeMaxBytes = "512M";
      };
      "20-root" = {
        Type = "root";
        Format = "btrfs";
        Label = "nixsapos-root";
      };
    };

    image.repart = {
      name = "nixsapos";
      partitions = lib.mkMerge [
        (lib.mapAttrs (name: settings: { repartConfig = settings; }) config.nixsapos.image.partitions)
        {
          # systemd-boot at the fallback path that UEFI firmware boots from removable drives.
          # It finds the unified kernel image (kernel, initrd, and kernel parameters in one file) on its own.
          "10-esp".contents = {
            "/EFI/BOOT/BOOTX64.EFI".source = "${config.systemd.package}/lib/systemd/boot/efi/systemd-bootx64.efi";
            "/EFI/Linux/nixsapos-initial.efi".source = "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
          };
          # Only at build time: install the system and make root as small as possible.
          # The first boot grows it to fill the drive.
          "20-root" = {
            storePaths = [ config.system.build.toplevel ];
            repartConfig.Minimize = "guess";
          };
        }
      ];
    };
  };
}
