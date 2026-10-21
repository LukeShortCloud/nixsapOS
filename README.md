# nixsapOS

nixsapOS is a portable [NixOS](https://nixos.org/) distribution that runs directly from USB drives and SD cards. It is an experimental port of [winesapOS](https://github.com/winesapOS/winesapOS) to NixOS.

**TABLE OF CONTENTS**

* [nixsapOS](#nixsapos)
   * [Comparison with winesapOS](#comparison-with-winesapos)
   * [Missing Features](#missing-features)


## Comparison with winesapOS

The nixsapOS column describes the planned proof-of-concept. It is updated as features land.

| Features | winesapOS 4 | nixsapOS |
| --- | --- | --- |
| Base distribution | Arch Linux or Manjaro | NixOS |
| Boot compatibility | UEFI and legacy BIOS | UEFI |
| Bootloader | GRUB (default) or systemd-boot | systemd-boot |
| Graphics drivers | AMD, Intel, NVIDIA, Parallels, QEMU/KVM (VirtIO-GPU Venus), VirtualBox, and VMware | AMD, Intel, NVIDIA (NVK and Nouveau only), and QEMU/KVM |
| Audio server | PipeWire | PipeWire |
| Read-only file system | No | No |
| Root file system | Btrfs | Btrfs |
| Logs | In RAM (persistent on the secure image) | In RAM (persistent on the encrypted image) |
| Root file system resize | During the first-time setup | Automatic on first boot |
| Encrypted file system | Yes (secure image) | Yes (secure image) |
| System rollbacks | Btrfs snapshots | NixOS generations (up to 5) |
| File system backups | Btrfs snapshots (Snapper) | No |
| Package managers (CLI) | flatpak, homebrew, nix, pacman, paru and yay (AUR), and snap | flatpak and nix |
| Preferred package manager (CLI) | flatpak | nix |
| Package managers (GUI) | Discover (flatpak) and Shelly (AppImage, flatpak, pacman, and AUR) | Discover (flatpak) |
| Update type | Package manager | Declarative (`nixos-rebuild`) |
| Number of installed packages | Small (minimal image) or Large (performance and secure images) | Small |
| Productivity applications | Small (minimal image) or Large (performance and secure images) | Small (`minimal`) or Large (`free` or `unfree`) |
| Gaming applications | Small (minimal image) or Large (performance and secure images) | Small (`minimal`) or Large (`free` or `unfree`) |
| Image types | Minimal, performance, and secure | One (minimal) |
| Linux kernels | Linux LTS and Linux Nobara | Latest stable Linux |
| Additional hardware drivers (Apple Intel Mac, ASUS, AYANEO, Framework Computer, Microsoft Surface, and more) | Yes | No |
| Desktop environment | KDE Plasma 6 | KDE Plasma 6 |
| Desktop theme | Breeze | Breeze |
| Display manager | Plasma Login Manager | Plasma Login Manager |
| Wine | Proton and GE-Proton | Proton and GE-Proton (`unfree`) |
| Game controller support | Large | Large (`minimal`, `free`, and `unfree`) |
| exFAT cross-platform storage | Yes (16 GiB by default, optional) | Yes (16 GiB, mandatory) |
| Unique UUIDs per flashed drive | No | Partition UUIDs (regenerated on first boot) |
| First-time setup wizard | Yes | No |
| Build method | Container or virtual machine | Container |
| Pre-built release image | Yes (minimal and performance) | Yes |


## Missing Features

These are the major winesapOS features that nixsapOS does not have yet.

- **Boot**
    - Legacy BIOS support.
    - Dual-boot support (os-prober) and the Calamares installer.
    - Ventoy support.
- **Storage**
    - A published encrypted image. It can be built, but is not released yet.
    - Btrfs backups with Snapper and snap-pac.
    - Support for many additional file systems (APFS, Bcachefs, FATX, HFS+, ZFS, SSHFS, s3fs, and more). nixsapOS only has the NixOS defaults.
- **Gaming**
    - Emulators (RetroDECK and EmuDeck).
    - Steam extras (Decky Loader, NonSteamLaunchers, RemotePlayWhatever, and GameImage).
    - The Nexus Mods app. It was discontinued upstream.
- **Productivity**
    - balenaEtcher, Flatseal, and the ZeroTier GUI. They are not in nixpkgs.
    - Battery optimizations (TLP).
- **Package managers**
    - Homebrew and Snap.
- **Hardware**
    - Additional drivers for Apple Intel Macs (including T2), ASUS laptops, ASUS ROG Ally, AYANEO, Framework Computer, Lenovo Legion Go, Microsoft Surface, MSI Claw, OneXPlayer, and Valve Steam Deck.
- **Desktop**
    - Additional desktop environments (Cinnamon, COSMIC, GNOME, i3, Plasma Mobile, and Sway) and Xorg.
- **Setup and upgrades**
    - The first-time setup wizard.
    - The winesapOS Upgrade wizard.
- **Security (secure image)**
    - AppArmor, firewalld, CPU mitigations, and forced password resets.
- **Distribution formats**
    - Root file system tarball, container image, and Windows Subsystem for Linux (WSL).
