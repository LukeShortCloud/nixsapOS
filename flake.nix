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
      generations = ./modules/features/generations.nix;
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
        { nixsapos.image.flake = self; }
      ];
    };

    # The flake installed to /etc/nixos. Start a new one with `nix flake init -t github:LukeShortCloud/nixsapOS`.
    templates.default = {
      path = ./templates/host;
      description = "A nixsapOS system";
      welcomeText = "Add your own changes to configuration.nix. Apply them by running `sudo nixos-rebuild switch --flake .` in this directory.";
    };

    # Build the flashable raw disk image in output/ as root, in a privileged container: `nix run .#nixsapos-build`.
    packages.x86_64-linux.nixsapos-build = self.nixosConfigurations.nixsapos.config.system.build.nixsaposBuild;

    # Each reusable module must work on any NixOS system.
    checks.x86_64-linux = import ./checks { inherit self nixpkgs; };
  };
}
