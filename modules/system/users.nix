# Use "users.nix" for configuring the default user account.
{ ... }:

{
  security.sudo.wheelNeedsPassword = false;
  users.users.nixsap = {
    extraGroups = [ "wheel" ];
    initialPassword = "nixsap";
    isNormalUser = true;
  };
}
