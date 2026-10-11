{ ... }:

{
  security.sudo.wheelNeedsPassword = false;
  users.users.nixsap = {
    extraGroups = [ "wheel" ];
    initialPassword = "nixsap";
    isNormalUser = true;
  };
}
