# The nixsapOS profile: distro-specific settings. Exported as `nixosModules.default`.
{ lib, pkgs, ... }:

{
  imports = [
    ./features/gaming.nix
    ./features/graphics-foss.nix
    ./features/plasma.nix
    ./features/portable-hardware.nix
    ./features/productivity.nix
    ./system/base.nix
    ./system/desktop.nix
    ./system/linux.nix
    ./system/networking.nix
    ./system/users.nix
  ];

  # Defaults are set so that /etc/nixos/configuration.nix can change them.
  nixsapos.gaming = {
    enable = lib.mkDefault true;
    # "minimal" (default), "free" or "unfree".
    selection = lib.mkDefault "minimal";
  };
  nixsapos.graphicsFoss.enable = lib.mkDefault true;
  nixsapos.plasma = {
    enable = lib.mkDefault true;
    passwordlessLogin = lib.mkDefault true;
  };
  nixsapos.portableHardware.enable = lib.mkDefault true;
  nixsapos.productivity = {
    enable = lib.mkDefault true;
    # "minimal" (default), "free" or "unfree".
    selection = lib.mkDefault "minimal";
  };

  # git is required for some NixOS operations.
  programs.git.enable = true;
  # vim is provided as an alternative to the default nano text editor.
  programs.vim.enable = true;
}
