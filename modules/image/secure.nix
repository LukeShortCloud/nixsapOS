{ config, lib, ... }:

{
  config = lib.mkIf config.nixsapos.image.encryption.enable {
    # "sudo" asks for the user's password.
    security.sudo.wheelNeedsPassword = true;

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
  };
}
