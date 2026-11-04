{ self, nixpkgs }:

let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
in
{
  # The nixsapOS profile with the same /etc/nixos/configuration.nix as the image.
  # It boots in a systemd-nspawn container.
  profile-minimal = pkgs.testers.runNixOSTest {
    name = "profile-minimal";
    # The profile changes nixpkgs: the Jovian-NixOS overlay and the allowed unfree packages.
    node.pkgsReadOnly = false;
    containers.machine = { lib, ... }: {
      imports = [
        self.nixosModules.default
        ../templates/host/configuration.nix
      ];
      # configuration.nix sets this option. It comes from nixosModules.image. The test cannot use it because it has its own drive and boot loader.
      options.nixsapos.image.encryption.enable = lib.mkOption { type = lib.types.bool; };
      # CUPS refuses its own files because the Nix store is not owned by root in the test. It then retries every millisecond and floods the log.
      config.services.printing.enable = lib.mkForce false;
    };
    testScript = ''
      # These services fail in any container test and work on a real drive.
      container_failures = {
          # The Nix build sandbox does not allow setuid programs.
          "suid-sgid-wrappers.service",
          # The container cannot mount file systems.
          "var-lib-nfs-rpc_pipefs.mount",
          # The container has no network or Wi-Fi devices.
          "resolvconf.service",
          "wpa_supplicant.service",
      }


      machine.wait_for_unit("multi-user.target")

      with subtest("the nixsap user is in its groups"):
          groups = machine.succeed("id --name --groups nixsap").split()
          for group in ["networkmanager", "nopasswdlogin", "wheel"]:
              assert group in groups, f"nixsap is not in {group}: {groups}"

      with subtest("sshd is installed but not started"):
          machine.succeed("systemctl cat sshd.service")
          machine.fail("systemctl is-active sshd.service")

      with subtest("sudo needs no password"):
          machine.succeed("grep -E '^%wheel.*NOPASSWD' /etc/sudoers")

      with subtest("no failed services"):
          failed = set(machine.succeed("systemctl --failed --no-legend --plain | awk '{ print $1 }'").split())
          assert failed <= container_failures, f"failed services: {sorted(failed - container_failures)}"
    '';
  };
}
