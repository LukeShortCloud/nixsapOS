# Use "linux.nix" for configuring Linux kernel related settings.
{ ... }:

{
  boot.kernel.sysctl = {
    # zram tuning.
    # https://rootpages.lukeshort.cloud/storage/file_systems.html#zram
    "vm.page-cluster" = 1;
    "vm.swappiness" = 180;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
  };
  zramSwap = {
    algorithm = "lz4";
    enable = true;
    memoryPercent = 200;
  };
}
