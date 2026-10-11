{ ... }:

{
  boot.kernelParams = [
    # Never suspend USB devices, including the drive nixsapOS runs from.
    "usbcore.autosuspend=-1"
    # Poll controllers, keyboards, and mice every 1 ms for lower input latency.
    "usbhid.jspoll=1"
    "usbhid.kbpoll=1"
    "usbhid.mousepoll=1"
  ];
  boot.kernel.sysctl = {
    # Increase the open files limit for system processes.
    "fs.file-max" = 524288;
    # Increase memory mapping limit.
    "vm.max_map_count" = 16777216;
    # Cache more writes in RAM for fewer writes to the drive.
    "vm.dirty_background_ratio" = 40;
    "vm.dirty_ratio" = 80;
    "vm.vfs_cache_pressure" = 50;
    # zram tuning.
    # https://rootpages.lukeshort.cloud/storage/file_systems.html#zram
    "vm.page-cluster" = 1;
    "vm.swappiness" = 180;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
  };
  # Increase the open files limit for user processes.
  systemd.user.extraConfig = "DefaultLimitNOFILE=524288";
  zramSwap = {
    algorithm = "lz4";
    enable = true;
    memoryPercent = 200;
  };
}
