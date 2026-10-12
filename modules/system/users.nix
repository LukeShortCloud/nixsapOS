{ ... }:

{
  security.sudo.wheelNeedsPassword = false;
  users.users.nixsap = {
    extraGroups = [
      # Log in without a password.
      "nopasswdlogin"
      # Enable "sudo".
      "wheel"
    ];
    initialPassword = "nixsap";
    isNormalUser = true;
  };
}
