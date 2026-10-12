{ config, lib, ... }:

let
  cfg = config.nixsapos.generations;
in
{
  options.nixsapos.generations = {
    enable = lib.mkEnableOption "a limit on how many NixOS generations (revisions) are kept";
    limit = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "How many NixOS generations to keep, including the current one.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Keep only the newest boot entries. On every rebuild, the kernels and initrds that
    # no remaining entry uses are deleted from the boot partition.
    boot.loader.grub.configurationLimit = cfg.limit;
    boot.loader.systemd-boot.configurationLimit = cfg.limit;

    # Regularly delete older generations and garbage-collect the Nix store.
    programs.nh = {
      enable = true;
      clean = {
        enable = true;
        extraArgs = "--keep ${toString cfg.limit}";
      };
    };
  };
}
