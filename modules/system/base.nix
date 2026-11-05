{ lib, ... }:

{
  # Shown in the boot menu, /etc/os-release and the TTY login. The ID stays "nixos" for tools that check it.
  system.nixos.distroName = "nixsapOS";

  # KMSCON replaces the getty on the virtual consoles (CTRL + ALT + F2 and higher)
  # It provides better fonts, resolution scaling, and Unicode character support.
  services.kmscon = {
    enable = true;
    # Use the same keyboard layout as the desktop.
    useXkbConfig = true;
  };

  # Set the time zone from the location. GeoClue finds it from the nearby Wi-Fi networks.
  # It changes as soon as the location changes and is not affected by a VPN.
  services.automatic-timezoned.enable = lib.mkDefault true;
}
