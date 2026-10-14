{
  description = "My nixsapOS system";

  inputs.nixsapos.url = "github:LukeShortCloud/nixsapOS";

  outputs = { nixsapos, ... }: {
    # Rebuild with `sudo nixos-rebuild switch`. Update nixsapOS with `nix flake update` first.
    nixosConfigurations.nixsapos = nixsapos.inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nixsapos.nixosModules.default
        nixsapos.nixosModules.image
        { nixsapos.image.flake = nixsapos; }
        ./configuration.nix
        ./image.nix
      ];
    };
  };
}
