{ ... }:

{
  i18n.defaultLocale = "en_US.UTF-8";
  networking.hostName = "nixsapos";
  time.timeZone = "UTC";

  # Shown in the boot menu, /etc/os-release and the TTY login. The ID stays "nixos" for tools that check it.
  system.nixos.distroName = "nixsapOS";
}
