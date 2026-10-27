{ config, lib, ... }:

{
  # The secure image, like the winesapOS secure image. It is the image with an encrypted root partition.
  config = lib.mkIf config.nixsapos.image.encryption.enable {
    # "sudo" asks for the user's password.
    security.sudo.wheelNeedsPassword = true;
  };
}
