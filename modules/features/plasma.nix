{ config, lib, ... }:

let
  cfg = config.nixsapos.plasma;
in
{
  options.nixsapos.plasma.enable = lib.mkEnableOption "the KDE Plasma 6 desktop with the Plasma Login Manager";

  config = lib.mkIf cfg.enable {
    # Plasma includes Dolphin, Gwenview, Kate, Konsole, Spectacle, thumbnailers, and the on-screen keyboard.
    services.desktopManager.plasma6.enable = true;

    # The new KDE login screen that replaces SDDM.
    services.displayManager.plasma-login-manager = {
      enable = true;
      # Use Wayland for the login screen.
      settings.General.DisplayServer = "wayland";
    };

    # Phone integration. This also opens the firewall ports it needs.
    programs.kdeconnect.enable = true;
  };
}
