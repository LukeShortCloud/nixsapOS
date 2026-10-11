# The nixsapOS profile: distro-specific settings. Exported as `nixosModules.default`.
{ ... }:

{
  imports = [
    ./system/base.nix
    ./system/boot.nix
    ./system/linux.nix
    ./system/networking.nix
    ./system/users.nix
  ];

  system.stateVersion = "26.05";
}
