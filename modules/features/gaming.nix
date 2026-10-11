{ config, lib, ... }:

let
  cfg = config.nixsapos.gaming;
in
{
  options.nixsapos.gaming.enable = lib.mkEnableOption "gaming support";

  config = lib.mkIf cfg.enable {
    # 32-bit graphics drivers are required for Steam and Wine.
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
}
