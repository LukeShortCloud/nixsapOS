{ config, lib, ... }:

let
  # A repart.d(5) setting value. For example: "esp", 512, true, or a list for repeated settings.
  repartValue = with lib.types; oneOf [ str int bool (listOf str) ];
in
{
  imports = [
    ./boot.nix
    ./build.nix
    ./drive.nix
    ./encryption.nix
    ./first-boot.nix
    ./secure.nix
  ];

  # Partition definitions shared by the image build and the first boot (systemd.repart).
  options.nixsapos.image.partitions = lib.mkOption {
    # Partition name -> repart setting name -> value.
    type = lib.types.attrsOf (lib.types.attrsOf repartValue);
    default = { };
    description = "systemd-repart settings for each partition, in the format of repart.d(5).";
  };

  # A rebuild must never remove the only user who can log in and use "sudo".
  # For example, after updating from a release that created the user outside of /etc/nixos/configuration.nix.
  config.assertions = [
    {
      assertion = lib.any (user: user.isNormalUser && lib.elem "wheel" user.extraGroups) (lib.attrValues config.users.users)
        || lib.any (name: config.users.users.${name}.isNormalUser or false) config.users.groups.wheel.members;
      message = ''
        No normal user is an administrator (in the "wheel" group). Without one, nobody can log in and use "sudo".
        Add a user to /etc/nixos/configuration.nix:
          users.users.nixsap = {
            extraGroups = [ "networkmanager" "nopasswdlogin" "wheel" ];
            isNormalUser = true;
          };
      '';
    }
  ];

  config.nixsapos.image.partitions = {
    "10-esp" = {
      Type = "esp";
      Format = "vfat";
      Label = "NXS-EFI";
      SizeMinBytes = "512M";
      SizeMaxBytes = "512M";
      # Use 512-byte sectors.
      # Older UEFI firmware cannot read FAT32 partitions with the modern default of 4096 bytes.
      FileSystemSectorSize = 512;
    };
    "20-root" = {
      Type = "root";
      Format = "btrfs";
      Label = "nixsapos-root";
    };
  };
}
