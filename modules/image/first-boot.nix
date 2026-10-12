{ config, lib, pkgs, ... }:

let
  nix = config.nix.package.out;
  # The list of store paths in the image, in the format of `nix-store --load-db`.
  closure = pkgs.closureInfo { rootPaths = [ config.system.build.toplevel ]; };
in
{
  image.repart.partitions."20-root".contents."/nix-path-registration".source = "${closure}/registration";

  # The image build copies the store paths but cannot register them in the Nix database.
  # Register them on the first boot, similar to the official NixOS SD card image.
  systemd.services.register-nix-paths = {
    description = "Register Nix Store Paths";
    unitConfig = {
      DefaultDependencies = false;
      ConditionPathExists = "/nix-path-registration";
    };
    wantedBy = [ "sysinit.target" ];
    before = [
      "sysinit.target"
      "shutdown.target"
      "nix-daemon.socket"
      "nix-daemon.service"
    ];
    after = [ "local-fs.target" ];
    conflicts = [ "shutdown.target" ];
    restartIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${lib.getExe' nix "nix-store"} --load-db < /nix-path-registration
      # nixos-rebuild requires the "system" profile.
      ${lib.getExe' nix "nix-env"} -p /nix/var/nix/profiles/system --set /run/current-system
      # Only run once.
      rm /nix-path-registration
    '';
  };
}
