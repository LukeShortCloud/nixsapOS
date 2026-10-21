{ self, nixpkgs }:

let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;

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
  gaming = checkModules "gaming" [
    self.nixosModules.gaming
    { nixsapos.gaming.enable = true; }
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
