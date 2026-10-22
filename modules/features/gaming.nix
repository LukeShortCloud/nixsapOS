{ config, lib, pkgs, ... }:

let
  cfg = config.nixsapos.gaming;
  # Each level includes the one before it.
  free = cfg.selection != "minimal";
  unfree = cfg.selection == "unfree";
  # The full package adds 16 cores with non-commercial licenses, such as Snes9x and FBNeo.
  retroarch = if unfree then pkgs.retroarch-full else pkgs.retroarch-free;
in
{
  options.nixsapos.gaming = {
    enable = lib.mkEnableOption "gaming support";
    selection = lib.mkOption {
      type = lib.types.enum [ "minimal" "free" "unfree" ];
      default = "minimal";
      description = ''
        Which gaming applications to install.
        "minimal" adds the graphics drivers and game tuning tools. "free" adds all open source launchers and utilities.
        "unfree" adds all open source and proprietary applications, such as Steam and Discord.
        Only the proprietary packages that this module adds are allowed, unless `nixpkgs.config` already allows them.
        "unfree" also installs RetroDECK as a Flatpak, which needs a desktop with XDG desktop portals (`xdg.portal`).
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # 32-bit graphics drivers are required for Steam and Wine.
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
      # Install GameMode. It is not used by default because it can hurt performance in some games.
      # Example Steam launch option usage: `gamemoderun %command%`.
      programs.gamemode.enable = true;
      # The micro-compositor used by the Steam Deck.
      programs.gamescope.enable = true;
      # A performance overlay for 64-bit and 32-bit games.
      environment.systemPackages = with pkgs; [
        mangohud
        pkgsi686Linux.mangohud
      ];

      # Controllers built into gaming handhelds.
      services.inputplumber.enable = true;
      # The NixOS module does not install the suspend service that comes with InputPlumber.
      # This is the same unit, so that controllers keep working after sleep.
      systemd.services.inputplumber-suspend = {
        description = "InputPlumber Suspend Inhibit Service";
        before = [ "sleep.target" ];
        wantedBy = [ "sleep.target" ];
        unitConfig.StopWhenUnneeded = true;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${config.systemd.package}/bin/busctl call org.shadowblip.InputPlumber /org/shadowblip/InputPlumber/Manager org.shadowblip.InputManager HookSleep";
          ExecStop = "${config.systemd.package}/bin/busctl call org.shadowblip.InputPlumber /org/shadowblip/InputPlumber/Manager org.shadowblip.InputManager HookWake";
        };
      };
      # Steam Controller, Steam Deck and Valve Index rules. Steam itself is not needed.
      hardware.steam-hardware.enable = true;
      # Rules for many more controllers. They need the virtual input device (uinput).
      services.udev.packages = [ pkgs.game-devices-udev-rules ];
      hardware.uinput.enable = true;
    }
    (lib.mkIf free {
      environment.systemPackages = with pkgs; [
        # Controller and racing wheel tools.
        antimicrox
        oversteer
        ## RGB lighting for Razer devices.
        polychromatic
        # Emulators.
        retroarch
        # Game launchers.
        bottles
        heroic
        ## The full Lutris package includes the unfree Steam package.
        lutris-free
        prismlauncher
        umu-launcher
        # Game tuning.
        goverlay
        vkbasalt
        # Game streaming.
        chiaki-ng
        moonlight-qt
        # Utilities.
        dosbox-staging
        ludusavi
        # Wine tools.
        protontricks
        protonup-qt
      ];

      # A vide game console experience.
      programs.opengamepadui = {
        enable = true;
        gamescopeSession.enable = true;
      };
      # Racing wheel permissions for Oversteer.
      services.udev.packages = [ pkgs.oversteer ];
      # Razer devices. Every normal user can use them.
      hardware.openrazer = {
        enable = true;
        users = lib.attrNames (lib.filterAttrs (_: user: user.isNormalUser) config.users.users);
      };
      # Corsair keyboards and mice.
      hardware.ckb-next.enable = true;
      # Graphics card settings and overclocking.
      services.lact.enable = true;
      # Game recording and streaming.
      programs.obs-studio.enable = true;
      # Host games for Moonlight. It is installed but not started by default.
      services.sunshine = {
        enable = true;
        autoStart = false;
        capSysAdmin = true;
        openFirewall = true;
      };
    })
    (lib.mkIf unfree {
      programs.steam = {
        enable = true;
        # GE-Proton runs some games better than Valve's Proton.
        extraCompatPackages = [ pkgs.proton-ge-bin ];
        # "Game Mode" like on the Steam Deck, on the login screen.
        gamescopeSession.enable = true;
      };
      environment.systemPackages = [ pkgs.discord ];
      # The Xbox wireless USB dongle for PC has proprietary firmware.
      # It turns off the mt76x2u and xpad drivers.
      # xpad-noone is used for wired Xbox controllers.
      hardware.xone.enable = true;
      # RetroDECK provides emulators for many modern consoles (compared to RetroArch). It is only available as a Flatpak.
      # It is unfree because it includes RPCS3 which has a license conflict.
      services.flatpak = {
        enable = true;
        packages = [ { appId = "net.retrodeck.retrodeck"; origin = "flathub"; } ];
      };

      # Only allow the proprietary packages that this module adds. Lists from other modules are merged.
      nixpkgs.config.allowUnfreePackages = [
        "discord"
        # RetroArch cores in retroarch-full.
        "libretro-fbalpha2012"
        "libretro-fbneo"
        "libretro-fmsx"
        "libretro-genesis-plus-gx"
        "libretro-mame2000"
        "libretro-mame2003"
        "libretro-mame2003-plus"
        "libretro-mame2010"
        "libretro-mame2015"
        "libretro-opera"
        "libretro-picodrive"
        "libretro-snes9x"
        "libretro-snes9x2002"
        "libretro-snes9x2005"
        "libretro-snes9x2005-plus"
        "libretro-snes9x2010"
        "steam"
        "steam-unwrapped"
        "xone-dongle-firmware"
      ];
    })
  ]);
}
