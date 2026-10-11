{ pkgs, ... }:

{
  # SSH is installed but not enabled by default.
  environment.systemPackages = [ pkgs.openssh ];
  #services.openssh.enable = true;
  networking.networkmanager.enable = true;
  users.users.nixsap.extraGroups = [ "networkmanager" ];
}
