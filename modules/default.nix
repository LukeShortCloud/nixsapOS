# The nixsapOS profile: distro-specific settings. Exported as `nixosModules.default`.
{ ... }:

{
  imports = [
    ./features/gaming.nix
    ./features/graphics-foss.nix
    ./features/plasma.nix
    ./features/portable-hardware.nix
    ./system/base.nix
    ./system/desktop.nix
    ./system/linux.nix
    ./system/networking.nix
    ./system/users.nix
  ];

  nixsapos.gaming.enable = true;
  nixsapos.graphicsFoss.enable = true;
  nixsapos.plasma.enable = true;
  nixsapos.plasma.passwordlessLogin = true;
  nixsapos.portableHardware.enable = true;

  system.stateVersion = "26.05";
}
