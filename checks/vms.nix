{ self, nixpkgs }:

let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  testFlathub = import ./test-flathub.nix { inherit pkgs; };

  # Start the nixsapOS system of the image in a QEMU virtual machine and run the Python test script against it.
  # Unlike a container, it has its own kernel, udev, and storage devices. It requires KVM support.
  vmTest = name: { modules ? [ ], testScript }: pkgs.testers.runNixOSTest {
    inherit name;
    # The profile changes nixpkgs: the Jovian-NixOS overlay and the allowed unfree packages.
    node.pkgsReadOnly = false;
    nodes.machine = { lib, ... }: {
      imports = [
        self.nixosModules.default
        self.nixosModules.image
        ../templates/host/configuration.nix
      ] ++ modules;
      # The drive growth on the first boot would add the image's partitions to the test drive.
      boot.initrd.systemd.repart.enable = lib.mkForce false;
      virtualisation.memorySize = 4096;
    };
    testScript = ''
      # A unit that waits for missing hardware, such as a hypervisor device, delays the boot by minutes.
      machine.wait_for_unit("multi-user.target", timeout=120)

      ${testScript}

      with subtest("no failed services"):
          machine.succeed("test -z \"$(systemctl --failed --no-legend --plain)\"")
    '';
  };
in
{
  vm-image-minimal = vmTest "vm-image-minimal" {
    modules = [
      {
        # Extra empty drives that read zeros: NVMe, USB and SATA.
        virtualisation.qemu.options = [
          "-blockdev driver=null-co,node-name=nvme0,size=1073741824,read-zeroes=on"
          "-device nvme,serial=nixsapos-nvme,drive=nvme0"
          "-blockdev driver=null-co,node-name=usb0,size=1073741824,read-zeroes=on"
          "-device qemu-xhci,id=xhci"
          "-device usb-storage,bus=xhci.0,drive=usb0"
          "-blockdev driver=null-co,node-name=sata0,size=1073741824,read-zeroes=on"
          "-device ahci,id=sata"
          "-device ide-hd,bus=sata.0,drive=sata0"
          # The ports of the QEMU guest agent and SPICE, with nothing connected on the host.
          "-device virtio-serial,id=serial0"
          "-chardev null,id=qga0"
          "-device virtserialport,bus=serial0.0,chardev=qga0,name=org.qemu.guest_agent.0"
          "-chardev null,id=spice0"
          "-device virtserialport,bus=serial0.0,chardev=spice0,name=com.redhat.spice.0"
        ];
      }
    ];
    testScript = ''
      with subtest("the kernel parameters"):
          cmdline = machine.succeed("cat /proc/cmdline").split()
          for parameter in ["mitigations=off", "usbcore.autosuspend=-1", "usbhid.jspoll=1", "usbhid.kbpoll=1", "usbhid.mousepoll=1"]:
              assert parameter in cmdline, f"{parameter} is not in {cmdline}"

      with subtest("BFQ for USB and SATA drives, and Kyber for NVMe drives"):
          machine.succeed("grep -q '\\[kyber\\]' /sys/block/nvme0n1/queue/scheduler")
          sata_and_usb = machine.succeed("ls -d /sys/block/sd*").split()
          assert len(sata_and_usb) == 2, f"expected a SATA and a USB drive: {sata_and_usb}"
          for drive in sata_and_usb:
              machine.succeed(f"grep -q '\\[bfq\\]' {drive}/queue/scheduler")

      with subtest("fewer writes to the drive"):
          # The journal is in /run (RAM). The test drive replaces the /var/log tmpfs, which scripts/nixsapos-tests.sh checks on a booted drive.
          machine.succeed("journalctl --header | grep -q 'File path: /run/log/journal/'")
          machine.succeed("test \"$(findmnt --noheadings --output FSTYPE /tmp)\" = tmpfs")
          machine.succeed("test \"$(sysctl --values vm.dirty_ratio)\" = 80")

      with subtest("zram swap with lz4"):
          machine.succeed("swapon --show=NAME --noheadings | grep -q zram")
          machine.succeed("grep -q '\\[lz4\\]' /sys/block/zram0/comp_algorithm")
          machine.succeed("test \"$(sysctl --values vm.swappiness)\" = 180")

      with subtest("only the QEMU guest tools start"):
          machine.wait_for_unit("qemu-guest-agent.service")
          machine.wait_for_unit("spice-vdagentd.service")
          for unit in ["virtualbox.service", "vmware.service", "hv-kvp.service", "xe-daemon.service", "xe-linux-distribution.service"]:
              machine.fail(f"systemctl is-active {unit}")

      with subtest("the login screen starts"):
          machine.wait_for_unit("display-manager.service")
    '';
  };

  vm-kernel-modules = vmTest "vm-kernel-modules" {
    modules = [
      { nixsapos.gaming.selection = "unfree"; }
      # The tests have no network. RetroDECK is installed from the offline stand-in (test-flathub.nix).
      ({ lib, ... }: { services.flatpak.remotes = lib.mkForce [ { name = "flathub"; location = "${testFlathub}/flathub.flatpakrepo"; } ]; })
    ];
    testScript = ''
      with subtest("the Razer drivers are loaded at boot"):
          machine.succeed("lsmod | grep -q '^razerkbd '")

      with subtest("the Xbox controller drivers load for the running kernel"):
          # They only load when a controller is plugged in. The xpad driver is replaced by xone and xpad-noone.
          for module in ["xone_dongle", "xone_gip", "xpad_noone"]:
              machine.succeed(f"modprobe {module}")
          machine.succeed("grep -qx 'blacklist xpad' /etc/modprobe.d/nixos.conf")
    '';
  };
}
