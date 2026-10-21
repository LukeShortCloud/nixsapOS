{ config, lib, pkgs, ... }:

let
  cfg = config.nixsapos.gaming;
  # Each level includes the one before it.
  free = cfg.selection != "minimal";
  unfree = cfg.selection == "unfree";
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
    }
    (lib.mkIf free {
      environment.systemPackages = with pkgs; [
        # Game launchers.
        bottles
        heroic
        # The full lutris package includes Steam, which is proprietary.
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

      # A game launcher for handhelds, with its own login screen session.
      programs.opengamepadui = {
        enable = true;
        gamescopeSession.enable = true;
      };
      # Graphics card settings and overclocking.
      services.lact.enable = true;
      # Game recording and streaming.
      programs.obs-studio.enable = true;
      # Host games for Moonlight. It is installed but not started, so the open ports have nothing listening by default.
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

      # Only allow the proprietary packages that this module adds. Lists from other modules are merged.
      nixpkgs.config.allowUnfreePackages = [
        "discord"
        "steam"
        "steam-unwrapped"
      ];
    })
  ]);
}
