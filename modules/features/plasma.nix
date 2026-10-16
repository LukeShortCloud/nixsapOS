{ config, lib, pkgs, ... }:

let
  cfg = config.nixsapos.plasma;
in
{
  options.nixsapos.plasma = {
    enable = lib.mkEnableOption "KDE Plasma 6 desktop with the Plasma Login Manager";
    passwordlessLogin = lib.mkEnableOption ''
      Login and unlock the screen without a password for members of the `nopasswdlogin` group.
      This helps on gaming handhelds without a keyboard and when switching desktop sessions.
    '';
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Plasma includes Dolphin, Gwenview, Kate, Konsole, Spectacle, thumbnailers, and the on-screen keyboard.
      services.desktopManager.plasma6.enable = true;

      services.displayManager.plasma-login-manager = {
        enable = true;
        # Use Wayland for the login screen.
        settings.General.DisplayServer = "wayland";
      };

      # PipeWire gets installed automatically as part of Plasma.
      # Use real-time priority to avoid audio crackling.
      security.rtkit.enable = lib.mkDefault config.services.pipewire.enable;

      # Phone integration. This also opens the firewall ports it needs.
      programs.kdeconnect.enable = true;

      # Add AppImage support.
      # binfmt runs AppImages directly (./app.AppImage) through appimage-run.
      programs.appimage.enable = true;
      programs.appimage.binfmt = true;

      # Add Flatpak support. Plasma already provides the XDG desktop portals (KDE and GTK) that Flatpak needs.
      # It also adds Discover and the Flatpak settings page when Flatpak is enabled.
      services.flatpak.enable = true;
      # Add the Flathub remote without a network connection or first-boot service.
      # Flatpak adds every remote in this directory when it creates the system installation.
      environment.etc."flatpak/remotes.d/flathub.flatpakrepo".source = ../../rootfs/etc/flatpak/remotes.d/flathub.flatpakrepo;

      # The Plasma meta package does not provide any web browser.
      programs.firefox = {
          enable = true;
          package = pkgs.firefox-esr;
      };
    }
    (lib.mkIf cfg.passwordlessLogin {
      users.groups.nopasswdlogin = { };
      # Skip the password for the login screen (plasmalogin) and the lock screen (kde).
      security.pam.services = lib.genAttrs [ "kde" "plasmalogin" ] (service: {
        rules.auth.nopasswdlogin = {
          # Before all of the other rules, which start at 10100.
          order = 10000;
          control = "sufficient";
          modulePath = "${config.security.pam.package}/lib/security/pam_succeed_if.so";
          args = [ "user" "ingroup" "nopasswdlogin" ];
        };
      });
    })
  ]);
}
