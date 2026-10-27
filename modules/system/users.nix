{ lib, ... }:

{
  # Use "sudo" without a password. The users are in /etc/nixos/configuration.nix.
  # The secure image asks for one (modules/image/secure.nix).
  security.sudo.wheelNeedsPassword = lib.mkDefault false;
}
