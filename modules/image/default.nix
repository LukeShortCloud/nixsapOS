{ lib, ... }:

let
  # A repart.d(5) setting value. For example: "esp", 512, true, or a list for repeated settings.
  repartValue = with lib.types; oneOf [ str int bool (listOf str) ];
in
{
  # Partition definitions shared by the image build (image.repart) and the first boot (systemd.repart).
  options.nixsapos.image.partitions = lib.mkOption {
    # Partition name -> repart setting name -> value.
    type = lib.types.attrsOf (lib.types.attrsOf repartValue);
    default = { };
    description = "systemd-repart settings for each partition, in the format of repart.d(5).";
  };

  config.nixsapos.image.partitions = {
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
}
