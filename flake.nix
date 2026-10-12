{
  description = "nixsapOS: a portable NixOS distribution that runs from a USB drive";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs }: {
    # Reusable NixOS modules. Other flakes can import these.
    nixosModules = {
      default = ./modules;
      gaming = ./modules/features/gaming.nix;
      graphics-foss = ./modules/features/graphics-foss.nix;
      image = ./modules/image;
      portable-hardware = ./modules/features/portable-hardware.nix;
    };

    # A complete nixsapOS system built from the modules above.
    nixosConfigurations.nixsapos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.default
        self.nixosModules.image
      ];
    };

    # The flashable raw disk image. Build it with `nix build .#image`.
    packages.x86_64-linux = rec {
      image = self.nixosConfigurations.nixsapos.config.system.build.image;
      default = image;
    };

    # Each reusable module must work on any NixOS system.
    checks.x86_64-linux = import ./checks { inherit self nixpkgs; };
  };
}
