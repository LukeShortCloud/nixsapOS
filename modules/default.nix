# The nixsapOS profile: distro-specific settings. Exported as `nixosModules.default`.
{ ... }:

{
  imports = [
    ./features/gaming.nix
    ./features/generations.nix
    ./features/graphics-foss.nix
    ./features/portable-hardware.nix
    ./system/base.nix
    ./system/boot.nix
    ./system/linux.nix
    ./system/networking.nix
    ./system/users.nix
  ];

  nixsapos.gaming.enable = true;
  nixsapos.generations.enable = true;
  nixsapos.graphicsFoss.enable = true;
  nixsapos.portableHardware.enable = true;

  # `nh os switch` rebuilds from the flake installed in the image.
  programs.nh.flake = "/etc/nixos";

  system.stateVersion = "26.05";
}
