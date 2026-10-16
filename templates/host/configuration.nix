{ lib, pkgs, ... }:

{
  # Settings for this computer. They stay the same when switching to another NixOS-based distribution.
  i18n.defaultLocale = "en_US.UTF-8";
  networking.hostName = "nixsapos";
  time.timeZone = "UTC";

  users.users.nixsap = {
    extraGroups = [
      # Change network settings.
      "networkmanager"
      # Log in without a password.
      "nopasswdlogin"
      # Enable "sudo".
      "wheel"
    ];
    initialPassword = "nixsap";
    isNormalUser = true;
  };

  # The NixOS release this system was first installed with. Never change it, even after upgrading NixOS.
  system.stateVersion = "26.05";
  # Whether the drive was flashed from the encrypted image. Never change it, or the drive won't boot.
  nixsapos.image.encryption.enable = false;

  # sshd.service is installed but not enabled by default.
  services.openssh.enable = true;
  systemd.services.sshd.wantedBy = lib.mkForce [ ];

  # Add your own changes here. For example, to install more packages:
  # environment.systemPackages = [ pkgs.firefox ];
}
