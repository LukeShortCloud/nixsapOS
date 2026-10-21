{ config, lib, pkgs, ... }:

let
  cfg = config.nixsapos.productivity;
  # Each level includes the one before it.
  free = cfg.selection != "minimal";
  unfree = cfg.selection == "unfree";
in
{
  options.nixsapos.productivity = {
    enable = lib.mkEnableOption "productivity applications";
    selection = lib.mkOption {
      type = lib.types.enum [ "minimal" "free" "unfree" ];
      default = "minimal";
      description = ''
        Which productivity applications to install.
        "minimal" adds a few small applications. "free" adds all open source applications.
        "unfree" adds all open source and proprietary applications.
        Only the proprietary packages that this module adds are allowed, unless `nixpkgs.config` already allows them.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      environment.systemPackages = with pkgs; [
        kdePackages.kalk
        keepassxc
      ];
    }
    (lib.mkIf free {
      environment.systemPackages = with pkgs; [
        # Containers.
        distrobox
        # Media and office.
        calibre
        gimp
        libreoffice-qt6-fresh
        mpv
        snapshot
        vlc
        # Networking.
        modem-manager-gui
        ## ZeroTier One is installed but disabled by default.
        zerotierone
        #services.zerotierone.enable = true;
        # Storage tools.
        gparted
        qdirstat
        # Utilities.
        clamtk
        filezilla
        peazip
        qbittorrent
        tmate
      ];

      # Virtual CD and DVD drives. Users must be in the "cdrom" group.
      programs.cdemu.enable = true;
      # Download the virus databases once a day for ClamTk. The scanning daemon stays off because it uses about 1 GB of RAM.
      services.clamav.updater = {
        enable = true;
        interval = "daily";
        frequency = 1;
      };
      # Fan and pump control.
      programs.coolercontrol.enable = true;
      # Cellular modems for Modem Manager GUI.
      networking.modemmanager.enable = true;
      # Distrobox uses Podman.
      virtualisation.podman.enable = true;
      # Android applications. Waydroid downloads its Android image on first use.
      virtualisation.waydroid.enable = true;
    })
    (lib.mkIf unfree {
      environment.systemPackages = with pkgs; [
        google-chrome
        veracrypt
      ];
      # Only allow the proprietary packages that this module adds. Lists from other modules are merged.
      nixpkgs.config.allowUnfreePackages = [ "google-chrome" "veracrypt" ];
    })
  ]);
}
