# The nixsapOS profile: distro-specific settings. Exported as `nixosModules.default`.
{ ... }:

{
  imports = [
    ./features/portable-hardware.nix
    ./system/base.nix
    ./system/boot.nix
    ./system/linux.nix
    ./system/networking.nix
    ./system/users.nix
  ];

  nixsapos.portableHardware.enable = true;

  system.stateVersion = "26.05";
}
