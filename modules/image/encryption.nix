{ config, lib, pkgs, ... }:

let
  cfg = config.nixsapos.image.encryption;
  # The drive that systemd-boot started from.
  bootDisk = "/dev/disk/nixsapos-boot-disk";
  # systemd-repart labels the LUKS2 header "luks-" and the partition label.
  luksLabel = "luks-nixsapos-root";
  luksDevice = "/dev/disk/by-label/${luksLabel}";
  mapperName = "nixsapos-root";
  # The LUKS2 header subsystem after the password is set, until the drive has its own volume key.
  newVolumeKeyMarker = "nixsapos-new-volume-key";
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

    boot.initrd.luks.devices.${mapperName} = {
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

    # Finish setting up the encryption on the first boot, before root is mounted:
    # 1. Replace the empty password with one that the user chooses.
    # 2. Encrypt the drive again with a new volume key. Every drive flashed from the image starts with the same one.
    # The LUKS2 header subsystem records which step is next, so a power loss continues where it stopped.
    boot.initrd.systemd.initrdBin = [ pkgs.cryptsetup ];
    boot.initrd.systemd.storePaths = [ "${systemd}/bin/systemd-cryptenroll" ];
    boot.initrd.systemd.services.nixsapos-luks-setup = {
      description = "Set up the encrypted root partition";
      # Never mount root while the new volume key is only partly written, or data written there later can't be read.
      # If this fails, the boot stops instead.
      requiredBy = [ "sysroot.mount" ];
      after = [ "systemd-cryptsetup@nixsapos\\x2droot.service" ];
      before = [ "sysroot.mount" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        # Stay active, so that sysroot.mount does not start it a second time.
        RemainAfterExit = true;
        # Show the messages on the screen next to the password prompts.
        StandardOutput = "journal+console";
      };
      script = ''
        header="$(cryptsetup luksDump "${luksDevice}")"
        password=""

        # The build puts the empty password in key slot 0, and setting a password removes it.
        # Without slot 0, a power loss stopped this script before it changed the marker.
        if [[ "$header" == *"Subsystem:"*"${cfg.emptyPasswordMarker}"* && "$header" != *$'\n  0: luks2'* ]]; then
          cryptsetup config --label "${luksLabel}" --subsystem "${newVolumeKeyMarker}" "${luksDevice}"
          header="$(cryptsetup luksDump "${luksDevice}")"
        fi

        if [[ "$header" == *"Subsystem:"*"${cfg.emptyPasswordMarker}"* ]]; then
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
          if ! PASSWORD="" NEWPASSWORD="$password" ${systemd}/bin/systemd-cryptenroll --password --wipe-slot=empty "${luksDevice}"; then
            echo "The password could not be set. It will be asked for again on the next boot."
            exit 0
          fi
          # `cryptsetup config` always sets both the label and the subsystem, so keep the label.
          cryptsetup config --label "${luksLabel}" --subsystem "${newVolumeKeyMarker}" "${luksDevice}"
          echo "The password of the encrypted drive is set."
          header="$(cryptsetup luksDump "${luksDevice}")"
        fi

        # Continue after a power loss during the encryption, or start it.
        if [[ "$header" != *"online-reencrypt"* && "$header" != *"Subsystem:"*"${newVolumeKeyMarker}"* ]]; then
          echo "The encrypted drive is set up."
          exit 0
        fi
        # After a power loss, the password is needed again to continue.
        until [[ -n "$password" ]] && printf '%s' "$password" | cryptsetup open --test-passphrase --key-file - "${luksDevice}"; do
          password="$(${systemd}/bin/systemd-ask-password --timeout=0 "Enter the password of the encrypted drive again to finish setting it up:")"
        done

        echo "Encrypting the drive with its own key. This takes a few minutes, and continues after a power loss."
        # Print the progress every 10 seconds. `--batch-mode` would hide it.
        reencrypt_options=(--key-file - --active-name "${mapperName}" --progress-frequency 10)
        if [[ "$header" == *"online-reencrypt"* ]]; then
          reencrypt_options+=(--resume-only)
        else
          # Only encrypt the part of the drive that the file system uses. The first boot grows it later.
          fs_size=""
          while read -r key value _; do
            if [[ "$key" == "total_bytes" ]]; then
              fs_size="$value"
            fi
          done < <(btrfs inspect-internal dump-super "/dev/mapper/${mapperName}")
          # The unlocked volume must be the same size as the part to encrypt.
          printf '%s' "$password" | cryptsetup resize --key-file - --size "$(( fs_size / 512 ))" "${mapperName}"
          reencrypt_options+=(--device-size "$fs_size")
        fi
        printf '%s' "$password" | cryptsetup reencrypt "''${reencrypt_options[@]}" "${luksDevice}"
        # Make the unlocked volume fill the partition again.
        printf '%s' "$password" | cryptsetup resize --key-file - "${mapperName}"
        # Remove the marker. `cryptsetup config` always sets both the label and the subsystem, so keep the label.
        cryptsetup config --label "${luksLabel}" "${luksDevice}"
        echo "The encrypted drive is set up."
      '';
    };
  };
}
