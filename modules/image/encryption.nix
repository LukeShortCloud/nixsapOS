{ config, lib, pkgs, ... }:

let
  cfg = config.nixsapos.image.encryption;
  # The drive that systemd-boot started from.
  bootDisk = "/dev/disk/nixsapos-boot-disk";
  # systemd-repart labels the LUKS2 header "luks-" and the partition label.
  luksLabel = "luks-nixsapos-root";
  luksDevice = "/dev/disk/by-label/${luksLabel}";
  systemd = config.boot.initrd.systemd.package;
in
{
  options.nixsapos.image.encryption = {
    enable = lib.mkEnableOption "LUKS2 encryption of the root partition";
    emptyPasswordMarker = lib.mkOption {
      type = lib.types.str;
      default = "nixsapos-empty-password";
      readOnly = true;
      internal = true;
      description = ''
        The LUKS2 header "subsystem" while the password is still empty. The image build sets it.
        Checking it is instant, while trying the empty password takes seconds on every boot.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # The build encrypts root with an empty password.
    # The Btrfs file system inside keeps the "nixsapos-root" label, so the root mount stays the same.
    nixsapos.image.partitions."20-root".Encrypt = "key-file";

    boot.initrd.luks.devices.nixsapos-root = {
      device = luksDevice;
      # Unlock without asking while the password is still empty.
      tryEmptyPassphrase = true;
    };
    # Wait for the password as long as it takes. Otherwise, waiting for the root file system times out after 90 seconds and starts the emergency shell.
    # systemd only does this by itself when root is mounted from /dev/mapper/nixsapos-root, but nixsapOS mounts it by label.
    fileSystems."/".options = [ "x-systemd.device-timeout=0" ];

    # Grow the root partition before it is unlocked, so the unlocked volume already fills it.
    # Growing it afterwards would need the volume key again to resize the volume (systemd-growfs fails with "Operation not permitted").
    # systemd-repart can only find the drive by itself after root is mounted, so give it the drive.
    # udev marks the drive with the partition that systemd-boot started from (ID_PART_GPT_AUTO_ROOT_DISK).
    boot.initrd.services.udev.rules = ''
      SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_PART_GPT_AUTO_ROOT_DISK}=="1", SYMLINK+="${lib.removePrefix "/dev/" bootDisk}"
    '';
    boot.initrd.systemd.repart.device = bootDisk;
    boot.initrd.systemd.services.systemd-repart.before = [ "systemd-cryptsetup@nixsapos\\x2droot.service" ];

    # Replace the empty password with one that the user chooses, on the first boot.
    boot.initrd.systemd.initrdBin = [ pkgs.cryptsetup ];
    boot.initrd.systemd.storePaths = [ "${systemd}/bin/systemd-cryptenroll" ];
    boot.initrd.systemd.services.nixsapos-luks-password = {
      description = "Set the password of the encrypted root partition";
      wantedBy = [ "initrd.target" ];
      after = [ "systemd-cryptsetup@nixsapos\\x2droot.service" ];
      before = [ "sysroot.mount" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        # Show the messages on the screen next to the password prompts.
        StandardOutput = "journal+console";
      };
      script = ''
        if [[ "$(cryptsetup luksDump "${luksDevice}")" != *"Subsystem:"*"${cfg.emptyPasswordMarker}"* ]]; then
          echo "The encrypted drive already has a password."
          exit 0
        fi

        while true; do
          password="$(${systemd}/bin/systemd-ask-password --timeout=0 "Create a password for the encrypted drive:")"
          if [[ -z "$password" ]]; then
            echo "The password cannot be empty."
            continue
          fi
          confirmation="$(${systemd}/bin/systemd-ask-password --timeout=0 "Enter the same password again:")"
          if [[ "$password" != "$confirmation" ]]; then
            echo "The passwords do not match."
          else
            break
          fi
        done

        echo "Setting the password. This can take a minute."
        # Unlock with the empty password (PASSWORD), add the new one (NEWPASSWORD), then remove the empty one.
        PASSWORD="" NEWPASSWORD="$password" ${systemd}/bin/systemd-cryptenroll --password --wipe-slot=empty "${luksDevice}"
        # Remove the marker. `cryptsetup config` always sets both the label and the subsystem, so keep the label.
        cryptsetup config --label "${luksLabel}" "${luksDevice}"
        echo "The password of the encrypted drive is set."
      '';
    };
  };
}
