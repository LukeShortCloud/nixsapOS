{ config, lib, ... }:

let
  cfg = config.nixsapos.graphicsFoss;
in
{
  options.nixsapos.graphicsFoss.enable = lib.mkEnableOption "free and open source graphics drivers only (Mesa and the Linux kernel)";

  config = lib.mkIf cfg.enable {
    # Mesa provides OpenGL and Vulkan for AMD, Intel, and NVIDIA (Nouveau and NVK).
    hardware.graphics.enable = true;

    assertions = [
      {
        assertion = !config.hardware.nvidia.enabled;
        message = "nixsapos.graphicsFoss only supports the free and open source NVIDIA drivers (Nouveau and NVK). Remove \"nvidia\" from services.xserver.videoDrivers.";
      }
    ];
  };
}
