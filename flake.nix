{
  description = "nixsapOS: a portable NixOS distribution that runs from a USB drive";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Declarative Flatpaks (services.flatpak.packages). Pinned to a release.
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.8.0";
  };

  outputs = { self, nixpkgs, nix-flatpak }: {
    # Reusable NixOS modules. Other flakes can import these.
    nixosModules = {
      # The gaming module installs Flatpaks declaratively, so nix-flatpak comes with it.
      # NixOS loads the same module path only once, even when it is imported twice.
      default = {
        imports = [ ./modules nix-flatpak.nixosModules.nix-flatpak ];
      };
      gaming = {
        imports = [ ./modules/features/gaming.nix nix-flatpak.nixosModules.nix-flatpak ];
      };
      graphics-foss = ./modules/features/graphics-foss.nix;
      # The drive. It also keeps this nixsapOS source in every generation, so /etc/nixos can rebuild offline.
      image = {
        imports = [ ./modules/image ];
        nixsapos.image.flake = self;
      };
      plasma = ./modules/features/plasma.nix;
      portable-hardware = ./modules/features/portable-hardware.nix;
      productivity = ./modules/features/productivity.nix;
    };

    # A complete nixsapOS system built from the modules above.
    nixosConfigurations.nixsapos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.default
        self.nixosModules.image
        # The same file that the image installs to /etc/nixos.
        ./templates/host/configuration.nix
      ];
    };
    # The secure image: the same system with an encrypted root partition.
    # The build writes `true` into its /etc/nixos/configuration.nix.
    nixosConfigurations.nixsapos-secure = self.nixosConfigurations.nixsapos.extendModules {
      modules = [ { nixsapos.image.encryption.enable = nixpkgs.lib.mkForce true; } ];
    };

    # The flake installed to /etc/nixos. Start a new one with `nix flake init -t github:LukeShortCloud/nixsapOS`.
    templates.default = {
      path = ./templates/host;
      description = "A nixsapOS system";
      welcomeText = "Add your own changes to configuration.nix. Apply them by running `sudo nixos-rebuild switch --flake .` in this directory.";
    };

    # Build the flashable raw disk image in $NIXSAPOS_OUTPUT_DIR as root, in a privileged container: `nix run .#nixsapos-build`.
    packages.x86_64-linux.nixsapos-build = self.nixosConfigurations.nixsapos.config.system.build.nixsaposBuild;
    # The secure image in $NIXSAPOS_OUTPUT_DIR/nixsapos-secure.img: `nix run .#nixsapos-build-secure`.
    packages.x86_64-linux.nixsapos-build-secure = self.nixosConfigurations.nixsapos-secure.config.system.build.nixsaposBuild;

    # Each reusable module must work on any NixOS system.
    checks.x86_64-linux = import ./checks { inherit self nixpkgs; };
  };
}
