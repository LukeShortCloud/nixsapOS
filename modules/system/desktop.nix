{ pkgs, ... }:

{
  # Disable KWallet for every user. Otherwise it asks for a password to unlock it after logging in.
  environment.etc."xdg/kwalletrc".source = ../../rootfs/etc/xdg/kwalletrc;

  # Printing. Plasma adds its printer settings when this is on.
  services.printing = {
    enable = true;
    # Print to Bluetooth printers. bluez provides the CUPS "bluetooth" backend.
    drivers = [ pkgs.bluez ];
    # A "pdf" printer that saves to ~/PDF, for apps without their own "Print to PDF".
    cups-pdf = {
      enable = true;
      instances.pdf.settings.Out = "\${HOME}/PDF";
    };
  };
  # Find network printers (mDNS). This opens UDP port 5353 in the firewall.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  # Firmware updates with "fwupdmgr" or Discover. Nothing is checked or installed until the user asks.
  # Plasma already turns this on by default. It is set here so it does not depend on Plasma.
  services.fwupd.enable = true;
  # Do not download the firmware list every hour in the background. This masks the timer.
  # "fwupdmgr refresh" and Discover still download it when the user asks.
  systemd.timers.fwupd-refresh.enable = false;
}
