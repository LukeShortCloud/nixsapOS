{ config, lib, ... }:

let
  cfg = config.nixsapos.portableHardware;
in
{
  options.nixsapos.portableHardware.enable = lib.mkEnableOption "drivers and firmware for booting on any PC";

  config = lib.mkIf cfg.enable {
    # Load storage and input drivers in the initrd for any PC and include all redistributable firmware.
    hardware.enableAllHardware = true;

    # Load CPU microcode updates for both vendors. The kernel only loads the one that matches the CPU.
    hardware.cpu.amd.updateMicrocode = true;
    hardware.cpu.intel.updateMicrocode = true;
  };
}
