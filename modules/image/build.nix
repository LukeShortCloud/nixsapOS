{ config, lib, pkgs, utils, ... }:

{
  # The partition definitions as repart.d(5) files, the same format as /etc/repart.d.
  system.build.nixsaposPartitions = utils.systemdUtils.lib.definitions "repart.d"
    (pkgs.formats.ini { listsAsDuplicateKeys = true; })
    (lib.mapAttrs (name: settings: { Partition = settings; }) config.nixsapos.image.partitions);

  # The image build script. It needs root for loop devices, so it runs in a privileged container.
  system.build.nixsaposBuild = pkgs.writeShellApplication {
    name = "nixsapos-build";
    runtimeInputs = [
      config.systemd.package
      pkgs.btrfs-progs
      pkgs.coreutils
      pkgs.dosfstools
    ];
    runtimeEnv = {
      NIXSAPOS_CLOSURE_INFO = pkgs.closureInfo { rootPaths = [ config.system.build.toplevel ]; };
      NIXSAPOS_ESP_SIZE = config.nixsapos.image.partitions."10-esp".SizeMaxBytes;
      NIXSAPOS_PARTITIONS = config.system.build.nixsaposPartitions;
    };
    text = builtins.readFile ../../scripts/nixsapos-build.sh;
  };
}
