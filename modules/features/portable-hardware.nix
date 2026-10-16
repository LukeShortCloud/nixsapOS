{ config, lib, ... }:

let
  cfg = config.nixsapos.portableHardware;
in
{
  options.nixsapos.portableHardware.enable = lib.mkEnableOption "drivers and firmware for booting on any PC";

  config = lib.mkIf cfg.enable {
    # Bluetooth with the adapter powered on at boot. Plasma adds its Bluetooth settings and applet when this is on.
    hardware.bluetooth.enable = true;
  };
}
