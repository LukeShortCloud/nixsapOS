{ config, lib, pkgs, ... }:

let
  secure = config.nixsapos.image.encryption.enable;
in
{
  config = lib.mkMerge [
    {
      # Only the secure image has a firewall.
      networking.firewall.enable = lib.mkDefault secure;
    }
    (lib.mkIf secure {
      # "sudo" asks for the user's password.
      security.sudo.wheelNeedsPassword = true;

      # Enable firewalld including the KDE Plasma "Firewall" application.
      services.firewalld.enable = true;
      # firewalld requires nftables.
      networking.nftables.enable = true;
      environment.systemPackages = [ pkgs.kdePackages.plasma-firewall ];

      # Only a subset of AppArmor profiles are applied.
      # NixOS uses non-standard paths so most community profiles will need to be modified.
      security.apparmor.enable = true;

      # Keep KWallet on so apps store their passwords encrypted. The minimal image turns it off (modules/system/desktop.nix).
      environment.etc."xdg/kwalletrc".enable = false;

      # Disable clipboard history.
      environment.etc."xdg/klipperrc".text = lib.generators.toINI { } {
        General = {
          KeepClipboardContents = false;
          MaxClipItems = 1;
          NoEmptyClipboard = false;
        };
      };
      # Klipper always writes the clipboard to a database file. Keep it in RAM instead.
      environment.etc."environment.d/60-nixsapos-klipper.conf".text = ''
        KLIPPER_DATABASE=''${XDG_RUNTIME_DIR}/klipper/history3.sqlite
      '';
    })
  ];
}
