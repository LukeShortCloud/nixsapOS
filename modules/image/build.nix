{ config, lib, pkgs, utils, ... }:

let
  flake = config.nixsapos.image.flake;
  template = "${flake}/templates/host";
  # Pin /etc/nixos to the nixsapOS source in the image so that it rebuilds offline.
  # `nix flake update` switches it to the newest nixsapOS from the template's URL.
  hostLock = {
    version = 7;
    root = "root";
    nodes = {
      root.inputs.nixsapos = "nixsapos";
      nixsapos = {
        inputs.nixpkgs = "nixpkgs";
        locked = { type = "path"; path = flake.outPath; inherit (flake) narHash; };
        original = builtins.parseFlakeRef (import "${template}/flake.nix").inputs.nixsapos.url;
      };
      nixpkgs = (lib.importJSON "${flake}/flake.lock").nodes.nixpkgs;
    };
  };
in
{
  options.nixsapos.image.flake = lib.mkOption {
    type = lib.types.nullOr lib.types.raw;
    default = null;
    description = "The nixsapOS flake that /etc/nixos uses: `self` in nixsapOS, or the `nixsapos` input of a host flake.";
  };

  config = lib.mkMerge [
    {
      # The partition definitions as repart.d(5) files, the same format as /etc/repart.d.
      system.build.nixsaposPartitions = utils.systemdUtils.lib.definitions "repart.d"
        (pkgs.formats.ini { listsAsDuplicateKeys = true; })
        (lib.mapAttrs (name: settings: { Partition = settings; }) config.nixsapos.image.partitions);
    }
    (lib.mkIf (flake != null) {
      # Keep the nixsapOS source in every generation so /etc/nixos can always rebuild offline.
      system.extraDependencies = [ flake.outPath ];

      # The host flake copied to /etc/nixos: the template plus its lock file.
      system.build.nixsaposHostFlake = pkgs.runCommand "nixsapos-host-flake" { } ''
        cp --recursive --no-preserve=mode ${template} $out
        cp ${pkgs.writeText "flake.lock" (builtins.toJSON hostLock)} $out/flake.lock
      '';

      # The image build script. It needs root for loop devices, so it runs in a privileged container.
      system.build.nixsaposBuild = pkgs.writeShellApplication {
        name = "nixsapos-build";
        runtimeInputs = [
          config.nix.package
          config.system.build.nixos-install
          config.systemd.package
          pkgs.btrfs-progs
          pkgs.coreutils
          pkgs.dosfstools
          pkgs.util-linux
        ];
        runtimeEnv = {
          NIXSAPOS_CLOSURE_INFO = pkgs.closureInfo { rootPaths = [ config.system.build.toplevel ]; };
          NIXSAPOS_ESP_SIZE = config.nixsapos.image.partitions."10-esp".SizeMaxBytes;
          NIXSAPOS_HOST_FLAKE = config.system.build.nixsaposHostFlake;
          NIXSAPOS_PARTITIONS = config.system.build.nixsaposPartitions;
          NIXSAPOS_TOPLEVEL = config.system.build.toplevel;
        };
        text = builtins.readFile ../../scripts/nixsapos-build.sh;
      };
    })
  ];
}
