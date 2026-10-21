# The nixsapOS profile: distro-specific settings. Exported as `nixosModules.default`.
{ pkgs, ... }:

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

  nixsapos.gaming = {
    enable = true;
    # "minimal" (default), "free" or "unfree".
    selection = "minimal";
  };
  nixsapos.graphicsFoss.enable = true;
  nixsapos.plasma = {
    enable = true;
    passwordlessLogin = true;
  };
  nixsapos.portableHardware.enable = true;
  nixsapos.productivity = {
    enable = true;
    # "minimal" (default), "free" or "unfree".
    selection = "minimal";
  };

  # git is required for some NixOS operations.
  programs.git.enable = true;
  # vim is provided as an alternative to the default nano text editor.
  programs.vim.enable = true;
}
