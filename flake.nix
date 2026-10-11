{
  description = "nixsapOS: a portable NixOS distribution that runs from a USB drive";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs }: {
    # Reusable NixOS modules. Other flakes can import these.
    nixosModules = {
      default = ./modules;
      portable-hardware = ./modules/features/portable-hardware.nix;
    };

    # A complete nixsapOS system built from the modules above.
    nixosConfigurations.nixsapos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.default
      ];
    };
  };
}
