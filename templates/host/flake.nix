{
  description = "My nixsapOS system";

  inputs.nixsapos.url = "github:LukeShortCloud/nixsapOS";

  outputs = { nixsapos, ... }: {
    # Rebuild with `sudo nixos-rebuild switch --flake /etc/nixos#nixsapos`. Update nixsapOS with `nix flake update` first.
    # Always use the configuration name (#nixsapos) when there is more than one.
    nixosConfigurations.nixsapos = nixsapos.inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nixsapos.nixosModules.default
        nixsapos.nixosModules.image
        ./configuration.nix
      ];
    };
  };
}
