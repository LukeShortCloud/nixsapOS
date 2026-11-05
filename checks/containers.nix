{ self, nixpkgs }:

let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  pythonList = list: "[${pkgs.lib.concatMapStringsSep ", " (item: ''"${item}"'') list}]";

  # An offline stand-in for Flathub, because the tests have no network.
  # It has a tiny "net.retrodeck.retrodeck" app and the runtime that it needs.
  # The real RetroDECK download is checked on a booted drive by scripts/nixsapos-tests.sh.
  testFlathub = pkgs.runCommand "test-flathub" { nativeBuildInputs = [ pkgs.flatpak ]; } ''
    export HOME="$TMPDIR"
    # An app has its files in files/. A runtime has them in usr/, but flatpak also needs files/ to exist.
    mkdir -p "$out" runtime/files runtime/usr app/files/bin
    cat > runtime/metadata <<EOF
    [Runtime]
    name=org.nixsapos.TestPlatform
    runtime=org.nixsapos.TestPlatform/x86_64/stable
    sdk=org.nixsapos.TestPlatform/x86_64/stable
    EOF
    flatpak build-export --runtime "$out/repo" runtime stable

    cat > app/metadata <<EOF
    [Application]
    name=net.retrodeck.retrodeck
    runtime=org.nixsapos.TestPlatform/x86_64/stable
    sdk=org.nixsapos.TestPlatform/x86_64/stable
    command=retrodeck
    EOF
    printf '#!/bin/sh\necho RetroDECK\n' > app/files/bin/retrodeck
    chmod +x app/files/bin/retrodeck
    flatpak build-finish app
    flatpak build-export "$out/repo" app stable

    flatpak build-update-repo "$out/repo"
    cat > "$out/flathub.flatpakrepo" <<EOF
    [Flatpak Repo]
    Title=Flathub (test)
    Url=file://$out/repo/
    EOF
  '';

  # Start a NixOS system with the given modules in a systemd-nspawn container and run the Python test script against it.
  # Every test also checks that no services failed, except for the ones in `container_failures`.
  containerTest = name: { modules, testScript }: pkgs.testers.runNixOSTest {
    inherit name;
    # The modules change nixpkgs: the Jovian-NixOS overlay and the allowed unfree packages.
    node.pkgsReadOnly = false;
    containers.machine = { lib, ... }: {
      imports = modules;
      # A normal user, like the one in /etc/nixos/configuration.nix.
      users.users.nixsap.isNormalUser = true;
      # CUPS refuses its own files because the Nix store is not owned by root in the test. It then retries every millisecond and floods the log.
      services.printing.enable = lib.mkForce false;
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


      def commands_exist(*commands):
          for command in commands:
              machine.succeed(f"test -x /run/current-system/sw/bin/{command}")


      def commands_missing(*commands):
          for command in commands:
              machine.fail(f"test -e /run/current-system/sw/bin/{command}")


      # Only checks that the services start at boot. Hardware daemons cannot run in a container.
      def services_enabled(*units):
          for unit in units:
              machine.succeed(f"systemctl is-enabled {unit}")


      machine.wait_for_unit("multi-user.target")

      ${testScript}

      with subtest("no failed services"):
          failed = set(machine.succeed("systemctl --failed --no-legend --plain | awk '{ print $1 }'").split())
          assert failed <= container_failures, f"failed services: {sorted(failed - container_failures)}"
    '';
  };

  # Commands from each level of the feature modules. Each level also has the commands of the levels before it.
  gamingFree = [ "heroic" "lutris" "retroarch" ];
  gamingUnfree = [ "Discord" "steam" ];
  productivityFree = [ "calibre" "gimp" "libreoffice" "vlc" ];
  productivityUnfree = [ "google-chrome-stable" "veracrypt" ];
in
{
  # The nixsapOS profile with the same /etc/nixos/configuration.nix as the image.
  container-profile-minimal = containerTest "container-profile-minimal" {
    modules = [
      self.nixosModules.default
      ../templates/host/configuration.nix
      # configuration.nix sets this option. It comes from nixosModules.image. The test cannot use it because it has its own drive and boot loader.
      ({ lib, ... }: { options.nixsapos.image.encryption.enable = lib.mkOption { type = lib.types.bool; }; })
    ];
    testScript = ''
      with subtest("the nixsap user is in its groups"):
          groups = machine.succeed("id --name --groups nixsap").split()
          for group in ["networkmanager", "nopasswdlogin", "wheel"]:
              assert group in groups, f"nixsap is not in {group}: {groups}"

      with subtest("sshd is installed but not started"):
          machine.succeed("systemctl cat sshd.service")
          machine.fail("systemctl is-active sshd.service")

      with subtest("sudo needs no password"):
          machine.succeed("grep -E '^%wheel.*NOPASSWD' /etc/sudoers")

      with subtest("KWallet is off"):
          machine.succeed("grep -qx Enabled=false /etc/xdg/kwalletrc")

      with subtest("the applications are at the minimal level"):
          commands_exist("git", "kalk", "keepassxc", "mangohud", "vim")
          commands_missing(*${pythonList (gamingFree ++ productivityFree)})
    '';
  };

  container-gaming-minimal = containerTest "container-gaming-minimal" {
    modules = [ self.nixosModules.gaming { nixsapos.gaming.enable = true; } ];
    testScript = ''
      with subtest("the minimal commands"):
          commands_exist("gamemoderun", "gamescope", "mangohud")
          commands_missing(*${pythonList (gamingFree ++ gamingUnfree)})

      with subtest("the services and settings"):
          machine.succeed("test -f /etc/gamemode.ini")
          services_enabled("inputplumber.service", "dmemcg-booster-system.service")
    '';
  };
  container-gaming-free = containerTest "container-gaming-free" {
    modules = [ self.nixosModules.gaming { nixsapos.gaming = { enable = true; selection = "free"; }; } ];
    testScript = ''
      with subtest("the free commands"):
          commands_exist(*${pythonList gamingFree})
          commands_missing(*${pythonList gamingUnfree})

      with subtest("the services"):
          services_enabled("ckb-next.service", "lactd.service")
          # Sunshine is a user service that is installed but does not start.
          machine.succeed("systemctl --global cat sunshine.service")
          machine.fail("systemctl --global is-enabled sunshine.service")

      with subtest("normal users can use Razer devices"):
          machine.succeed("id --name --groups nixsap | grep -qw openrazer")
    '';
  };
  container-gaming-unfree = containerTest "container-gaming-unfree" {
    modules = [
      self.nixosModules.gaming
      { nixsapos.gaming = { enable = true; selection = "unfree"; }; }
      # RetroDECK is a Flatpak, which needs XDG desktop portals. Plasma adds them on the image.
      { xdg.portal = { enable = true; extraPortals = [ pkgs.xdg-desktop-portal-gtk ]; config.common.default = "*"; }; }
      # The same remote name with the offline stand-in.
      ({ lib, ... }: { services.flatpak.remotes = lib.mkForce [ { name = "flathub"; location = "${testFlathub}/flathub.flatpakrepo"; } ]; })
    ];
    testScript = ''
      with subtest("the unfree commands"):
          commands_exist(*${pythonList (gamingFree ++ gamingUnfree)})

      with subtest("the services"):
          services_enabled("decky-loader.service")

      with subtest("RetroDECK is installed from the flathub remote"):
          machine.wait_until_succeeds("flatpak info --system net.retrodeck.retrodeck", timeout=120)
          machine.succeed("flatpak info --system --show-origin net.retrodeck.retrodeck | grep -qx flathub")
          # The install service finished without an error.
          machine.wait_until_succeeds("test \"$(systemctl show --property=ActiveState --value flatpak-managed-install.service)\" = inactive", timeout=60)
          machine.succeed("test \"$(systemctl show --property=Result --value flatpak-managed-install.service)\" = success")
    '';
  };

  container-graphics-foss = containerTest "container-graphics-foss" {
    modules = [ self.nixosModules.graphics-foss { nixsapos.graphicsFoss.enable = true; } ];
    testScript = ''
      with subtest("the graphics driver tools"):
          commands_exist("eglinfo", "glxinfo", "vkcube", "vulkaninfo")
    '';
  };

  container-plasma = containerTest "container-plasma" {
    modules = [ self.nixosModules.plasma { nixsapos.plasma = { enable = true; passwordlessLogin = true; }; } ];
    testScript = ''
      with subtest("the desktop and its applications"):
          commands_exist("dolphin", "firefox-esr", "konsole", "startplasma-wayland")

      with subtest("the Flathub remote exists without a network"):
          machine.succeed("flatpak remotes --system --columns=name | grep -qx flathub")

      with subtest("members of nopasswdlogin log in and unlock without a password"):
          for service in ["kde", "plasmalogin"]:
              machine.succeed(f"grep -q 'pam_succeed_if.so user ingroup nopasswdlogin' /etc/pam.d/{service}")

      with subtest("the user service workarounds"):
          machine.succeed("systemctl --global cat drkonqi-coredump-pickup.service | grep -qx RuntimeMaxSec=infinity")
          machine.succeed("systemctl --global cat xdg-document-portal.service | grep -qx TimeoutStopSec=5s")
    '';
  };

  container-portable-hardware = containerTest "container-portable-hardware" {
    modules = [ self.nixosModules.portable-hardware { nixsapos.portableHardware.enable = true; } ];
    testScript = ''
      with subtest("the hardware services"):
          services_enabled("bluetooth.service", "tlp.service")
          machine.succeed("systemctl cat fprintd.service usbmuxd.service")
          commands_exist("idevice_id")

      with subtest("fingerprints work for sudo but not for the login"):
          machine.succeed("grep -q pam_fprintd.so /etc/pam.d/sudo")
          machine.fail("grep -q pam_fprintd.so /etc/pam.d/login")

      with subtest("rpcbind is off (only NFSv4)"):
          machine.fail("systemctl is-enabled rpcbind.service rpcbind.socket")
          machine.succeed("test -z \"$(ss --listening --tcp --udp --numeric --no-header 'sport = :111')\"")
    '';
  };

  container-productivity-minimal = containerTest "container-productivity-minimal" {
    modules = [ self.nixosModules.productivity { nixsapos.productivity.enable = true; } ];
    testScript = ''
      with subtest("the minimal commands"):
          commands_exist("kalk", "keepassxc")
          commands_missing(*${pythonList (productivityFree ++ productivityUnfree)})
    '';
  };
  container-productivity-free = containerTest "container-productivity-free" {
    modules = [ self.nixosModules.productivity { nixsapos.productivity = { enable = true; selection = "free"; }; } ];
    testScript = ''
      with subtest("the free commands"):
          commands_exist(*${pythonList productivityFree})
          commands_missing(*${pythonList productivityUnfree})

      with subtest("the services"):
          services_enabled("clamav-freshclam.timer", "coolercontrold.service")
          # The scanning daemon uses about 1 GB of RAM, so only the virus database updater is on.
          machine.fail("systemctl is-enabled clamav-daemon.service")
    '';
  };
  container-productivity-unfree = containerTest "container-productivity-unfree" {
    modules = [ self.nixosModules.productivity { nixsapos.productivity = { enable = true; selection = "unfree"; }; } ];
    testScript = ''
      with subtest("the unfree commands"):
          commands_exist(*${pythonList (productivityFree ++ productivityUnfree)})
    '';
  };
}
