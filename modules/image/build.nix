{ config, lib, pkgs, utils, ... }:

let
  flake = config.nixsapos.image.flake;
  template = "${flake}/templates/host";
  # A flake's source and the sources of its inputs, and of their inputs.
  flakeSources = f: [ f.outPath ] ++ lib.concatMap flakeSources (lib.attrValues (f.inputs or { }));
  # The template's configuration.nix, with the encryption setting of this image.
  encryptionSetting = enable: "nixsapos.image.encryption.enable = ${lib.boolToString enable};";
  templateConfiguration = builtins.readFile "${template}/configuration.nix";
  hostConfiguration =
    assert lib.assertMsg (lib.hasInfix (encryptionSetting false) templateConfiguration)
      "templates/host/configuration.nix must contain `${encryptionSetting false}`.";
    pkgs.writeText "configuration.nix" (builtins.replaceStrings
      [ (encryptionSetting false) ]
      [ (encryptionSetting config.nixsapos.image.encryption.enable) ]
      templateConfiguration);
in
{
  options.nixsapos.image.flake = lib.mkOption {
    type = lib.types.nullOr lib.types.raw;
    default = null;
    description = "The nixsapOS flake that /etc/nixos uses. The `nixosModules.image` export sets it to nixsapOS itself.";
  };

  config = lib.mkMerge [
    {
      # The partition definitions as repart.d(5) files, the same format as /etc/repart.d.
      # Only at build time: all-zero partition UUIDs, which the first boot replaces with unique ones.
      system.build.nixsaposPartitions = utils.systemdUtils.lib.definitions "repart.d"
        (pkgs.formats.ini { listsAsDuplicateKeys = true; })
        (lib.mapAttrs (name: settings: { Partition = settings // { UUID = "null"; }; }) config.nixsapos.image.partitions);
    }
    (lib.mkIf (flake != null) {
      # Keep the nixsapOS source and the sources of all of its inputs in every generation so /etc/nixos can always rebuild offline.
      system.extraDependencies = lib.unique (flakeSources flake);

      # The host flake copied to /etc/nixos: the template with the encryption setting. The build script locks it.
      system.build.nixsaposHostFlake = pkgs.runCommand "nixsapos-host-flake" { } ''
        cp --recursive --no-preserve=mode ${template} $out
        cp ${hostConfiguration} $out/configuration.nix
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
          pkgs.cryptsetup
          pkgs.dosfstools
          pkgs.e2fsprogs
          pkgs.gawk
          pkgs.gnugrep
          pkgs.util-linux
        ];
        runtimeEnv = {
          NIXSAPOS_CLOSURE_INFO = pkgs.closureInfo { rootPaths = [ config.system.build.toplevel ]; };
          NIXSAPOS_ESP_SIZE = config.nixsapos.image.partitions."10-esp".SizeMaxBytes;
          NIXSAPOS_FLAKE_SOURCE = flake.outPath;
          NIXSAPOS_HOST_FLAKE = config.system.build.nixsaposHostFlake;
          NIXSAPOS_IMAGE_NAME = "nixsapos" + lib.optionalString config.nixsapos.image.encryption.enable "-secure";
          NIXSAPOS_PARTITIONS = config.system.build.nixsaposPartitions;
          # The same compression as the root mount options, for example "zstd:2".
          NIXSAPOS_ROOT_COMPRESSION = lib.removePrefix "compress-force="
            (lib.findFirst (lib.hasPrefix "compress-force=") "compress-force=no" config.fileSystems."/".options);
          NIXSAPOS_ROOT_EMPTY_PASSWORD_MARKER = config.nixsapos.image.encryption.emptyPasswordMarker;
          NIXSAPOS_ROOT_ENCRYPT = config.nixsapos.image.partitions."20-root".Encrypt or "off";
          NIXSAPOS_ROOT_LABEL = config.nixsapos.image.partitions."20-root".Label;
          NIXSAPOS_TOPLEVEL = config.system.build.toplevel;
        };
        text = builtins.readFile ../../scripts/nixsapos-build.sh;
      };
    })
  ];
}
