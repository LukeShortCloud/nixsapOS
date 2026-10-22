{ self, nixpkgs }:

let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;

  # Flatpak needs XDG desktop portal (automatically provided by KDE Plasma).
  desktopPortal = {
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = "*";
    };
  };

  # Evaluate a minimal NixOS system that only uses the given modules (no nixsapOS profile).
  # The check passes if the system evaluates. Nothing is built.
  checkModules = name: modules:
    let
      system = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = modules ++ [
          {
            boot.loader.grub.enable = false;
            fileSystems."/" = {
              device = "none";
              fsType = "tmpfs";
            };
            system.stateVersion = "26.05";
          }
        ];
      };
    in
    pkgs.writeText "check-${name}" (builtins.unsafeDiscardStringContext system.config.system.build.toplevel.drvPath);
in
{
  # Each level of applications.
  gaming-minimal = checkModules "gaming-minimal" [
    self.nixosModules.gaming
    { nixsapos.gaming.enable = true; }
  ];
  gaming-free = checkModules "gaming-free" [
    self.nixosModules.gaming
    { nixsapos.gaming = { enable = true; selection = "free"; }; }
  ];
  gaming-unfree = checkModules "gaming-unfree" [
    self.nixosModules.gaming
    desktopPortal
    { nixsapos.gaming = { enable = true; selection = "unfree"; }; }
  ];
  # Both features install proprietary packages and share one allow list.
  gaming-productivity-unfree = checkModules "gaming-productivity-unfree" [
    self.nixosModules.gaming
    self.nixosModules.productivity
    desktopPortal
    {
      nixsapos.gaming = { enable = true; selection = "unfree"; };
      nixsapos.productivity = { enable = true; selection = "unfree"; };
    }
  ];
  graphics-foss = checkModules "graphics-foss" [
    self.nixosModules.graphics-foss
    { nixsapos.graphicsFoss.enable = true; }
  ];
  plasma = checkModules "plasma" [
    self.nixosModules.plasma
    { nixsapos.plasma.enable = true; }
  ];
  portable-hardware = checkModules "portable-hardware" [
    self.nixosModules.portable-hardware
    { nixsapos.portableHardware.enable = true; }
  ];
  # Each level of applications.
  productivity-minimal = checkModules "productivity-minimal" [
    self.nixosModules.productivity
    { nixsapos.productivity.enable = true; }
  ];
  productivity-free = checkModules "productivity-free" [
    self.nixosModules.productivity
    { nixsapos.productivity = { enable = true; selection = "free"; }; }
  ];
  productivity-unfree = checkModules "productivity-unfree" [
    self.nixosModules.productivity
    { nixsapos.productivity = { enable = true; selection = "unfree"; }; }
  ];
}
