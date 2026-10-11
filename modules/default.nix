# The nixsapOS profile: distro-specific settings. Exported as `nixosModules.default`.
{ ... }:

{
  imports = [
    ./system/base.nix
  ];

  # Placeholders so the configuration evaluates. These are replaced in later steps.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixsapos-root";
    fsType = "btrfs";
  };
  boot.loader.grub.enable = false;

  system.stateVersion = "26.05";
}
