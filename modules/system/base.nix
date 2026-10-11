{ ... }:

{
  i18n.defaultLocale = "en_US.UTF-8";
  networking.hostName = "nixsapos";
  time.timeZone = "UTC";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
