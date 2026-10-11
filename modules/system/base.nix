# Use "base.nix" for configuring the default system identity.
{ ... }:

{
  i18n.defaultLocale = "en_US.UTF-8";
  networking.hostName = "nixsapos";
  time.timeZone = "UTC";
}
