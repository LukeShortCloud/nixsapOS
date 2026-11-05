# Contributing to nixsapOS

* [Contributing to nixsapOS](#contributing-to-nixsapos)
   * [Building the Image](#building-the-image)
      * [Task](#task)
      * [Podman](#podman)
      * [Docker](#docker)
      * [Secure Image](#secure-image)
      * [Build Cache](#build-cache)
      * [Git](#git)
      * [Why Not `nix build`](#why-not-nix-build)
   * [Configuration Files](#configuration-files)
   * [Testing the Image](#testing-the-image)
   * [GitHub Actions](#github-actions)
      * [Testing Workflows Locally](#testing-workflows-locally)

## Building the Image

nixsapOS is built in a container. The build machine only needs Podman or Docker. Building never uses a virtual machine. The container must be privileged because the build uses loop devices to install NixOS into the image.

The image is written to `~/.cache/nixsapos/nixsapos.img` (or `$XDG_CACHE_HOME/nixsapos/`). It is owned by the user who owns the repository, not by root.

The images are kept outside the repository on purpose. A `path:` flake reference copies the whole directory into the Nix store, ignoring `.gitignore`. Every evaluation would copy them (about 10 GB each). The build stops if `NIXSAPOS_OUTPUT_DIR` is missing or inside the repository.

### Task

[Task](https://taskfile.dev/) runs the commands in this document for you. They are defined in `Taskfile.yml`. Install it from your distribution (the package is usually named `go-task`) or from nixpkgs (`nix shell nixpkgs#go-task`). Some distributions and nixpkgs name the command `task` instead of `go-task`. Run it from the repository root. Run `go-task` with no arguments to list every task:

| Task | What it does (and where the manual steps are) |
| --- | --- |
| `go-task builder` | Create the builder container image ([Podman](#podman)). |
| `go-task build:minimal` | Build the minimal image ([Podman](#podman)). |
| `go-task build:secure` | Build the secure image ([Secure Image](#secure-image)). |
| `go-task build:all` | Build both images, one after the other. |
| `go-task check` | Evaluate the flake with `nix flake check --no-build` in the builder container ([GitHub Actions](#github-actions)). |
| `go-task test:nixos` | Run the NixOS tests in `checks/` ([NixOS Tests](#nixos-tests)). |
| `go-task test:nixos:interactive TEST=<NAME>` | Open the Python shell of one NixOS test ([NixOS Tests](#nixos-tests)). |
| `go-task vm:minimal` and `go-task vm:secure` | Boot an image in a virtual machine ([Testing the Image](#testing-the-image)). |
| `go-task test HOST=<USER>@<IP_ADDRESS>` | Run the runtime checks on a booted drive over SSH ([Testing the Image](#testing-the-image)). |
| `go-task cache:clean` and `go-task cache:delete` | Free up space in the Nix store volume or delete it ([Build Cache](#build-cache)). |
| `go-task update:inputs` | Update the flake inputs in `flake.lock`. |
| `go-task act:check` and `go-task act:build` | Run the workflows locally ([Testing Workflows Locally](#testing-workflows-locally)). |

The tasks use Podman when it is installed. Add `CONTAINER=docker` to use Docker instead, for example `go-task build:minimal CONTAINER=docker`.

### Podman

Podman is the recommended tool. It must run as root (`sudo`), because rootless containers cannot use loop devices.

```
output_dir="${XDG_CACHE_HOME:-$HOME/.cache}/nixsapos"
mkdir -p "${output_dir}"
sudo podman build -t nixsapos-builder build/
sudo podman run --rm --privileged -v /dev:/dev -v nixsapos-nix:/nix -v "$(pwd)":/workdir -w /workdir -v "${output_dir}":/output -e NIXSAPOS_OUTPUT_DIR=/output nixsapos-builder nix run .#nixsapos-build
```

Podman needs the output directory to exist, which is why it is created first.

### Docker

```
output_dir="${XDG_CACHE_HOME:-$HOME/.cache}/nixsapos"
mkdir -p "${output_dir}"
sudo docker build -t nixsapos-builder -f build/Containerfile build/
sudo docker run --rm --privileged -v /dev:/dev -v nixsapos-nix:/nix -v "$(pwd)":/workdir -w /workdir -v "${output_dir}":/output -e NIXSAPOS_OUTPUT_DIR=/output nixsapos-builder nix run .#nixsapos-build
```

Docker looks for a file named `Dockerfile` by default. The `Containerfile` is passed with `-f`.

### Secure Image

The secure image is the same system with a LUKS2-encrypted root partition. Build it with `go-task build:secure`. The manual Podman or Docker command is the same as for the minimal image, but ends with `nix run .#nixsapos-build-secure` instead of `nix run .#nixsapos-build`.

The build will be available at: `~/.cache/nixsapos/nixsapos-secure.img`.

Test it with `go-task vm:secure` or `scripts/nixsapos-test-vm.sh ~/.cache/nixsapos/nixsapos-secure.img`. The image has an empty password. It can be flashed and booted without one. The first boot:

1. Asks for a new drive password twice, on the console before root is mounted.
2. Gives the drive its own volume key, by re-encrypting the used part of root. This takes about 1.5 minutes and up to 1 GB of memory for an 8 GiB root, and it continues after a power loss.
3. Grows root to fill the drive, like the minimal image.

Every later boot asks for the drive password. Other differences from the minimal image:

- A firewall (firewalld), with a Firewall page in System Settings. The minimal image has none.
- AppArmor is on but it only confines programs that NixOS modules add profiles for. With `free` and `unfree` packages, there are profiles loaded for the LXC containers that Waydroid uses. With `minimal` packages, no profiles are loaded.
- `sudo` asks for the user's password. It is still the default `nixsap` until the first-time setup can change it.
- Logs are kept on the drive instead of in RAM.
- CPU vulnerability mitigations stay on.
- KWallet is on, and the clipboard keeps one item, in RAM only.

The secure-image-only settings are in `modules/image/secure.nix`, apart from the logs and mitigations in `modules/image/boot.nix`.

### Build Cache

The `nixsapos-nix` volume keeps the Nix store between builds. The first build downloads every package. Later builds only download and build what changed, for example about 2 minutes instead of 10.

- Delete the volume after changing the Nix version (`FROM`) in `build/Containerfile`, because the volume also holds the container's own copy of Nix: `go-task cache:delete`, `sudo podman volume rm nixsapos-nix` or `sudo docker volume rm nixsapos-nix`.
- Free up space by removing old packages from the volume: `go-task cache:clean`, or add `nix-collect-garbage` instead of `nix run .#nixsapos-build` to the end of the `run` command.
- Leave out `-v nixsapos-nix:/nix` to build without a cache.

### Git

Nix only sees files that are tracked by git. Run `git add` on new files before building. They do not need to be committed.

### Why Not `nix build`

NixOS can build disk images with a plain `nix build`, using the official [`image.repart`](https://nixos.org/manual/nixos/stable/#sec-image-repart) module. nixsapOS uses its own build instead: `nix run .#nixsapos-build` runs `nixos-install` into a loop-mounted image inside a privileged container.

The other official image builders, `make-disk-image.nix` and `nixos-rebuild build-image`, are not an option. They install the bootloader inside a QEMU virtual machine. nixsapOS requires building without that to run on free GitHub Actions runners.

Why `image.repart` was replaced:

- **It does not install NixOS. It only copies files.** The first boot had to finish the install, with a service that registers the Nix store and another that installs systemd-boot. The image also needed an extra boot entry (a unified kernel image) that only existed to boot that first time. `nixos-install` installs the system completely at build time, the same way as an install on a real PC. The first boot only grows the drive and creates unique UUIDs.
- **It corrupted some packages.** It copies symlinks in the Nix store as the files they point to. `nix-store --verify --check-contents` would fail. `nixos-install` copies the store with Nix itself.
- **It cannot encrypt.** The secure image uses LUKS2 encryption which needs dm-crypt. A privileged container has it.

Pros:

- The build uses the same official tools as a manual NixOS install (`nixos-install`, `systemd-repart`, `mkfs.btrfs`).
- The image is smaller. `mkfs.btrfs --shrink` makes root exactly as big as its files.

Cons:

- `nix build` alone cannot make the image. The build needs a privileged container or root on the host which means Podman cannot run rootless.
- The build is no longer a pure Nix derivation. The image itself is not cached or reproduced by Nix. The packages inside it still are.
- There is more of our own code to maintain: the script `scripts/nixsapos-build.sh` sizes, shrinks and cleans up the image instead of systemd-repart.
- Every build makes the whole image again, even when nothing changed (about 2 minutes with a warm cache). Nix would have reused an unchanged `image.repart` image.

## Configuration Files

Static configuration files live in `rootfs/` at the same path they have on the installed system. For example, `rootfs/etc/xdg/kwalletrc` becomes `/etc/xdg/kwalletrc`. The module that needs a file installs it with `environment.etc`:

```nix
environment.etc."xdg/kwalletrc".source = ../../rootfs/etc/xdg/kwalletrc;
```

Prefer a NixOS option when one exists for the setting, such as `services.displayManager.plasma-login-manager.settings`. Use `rootfs/` for files that NixOS has no option for.

## Testing the Image

Boot the image in a QEMU virtual machine with UEFI firmware:

```
$ go-task vm:minimal
```

The manual command is `scripts/nixsapos-test-vm.sh`.

It never changes `~/.cache/nixsapos/nixsapos.img`. It boots a copy in `~/.cache/nixsapos/vm/`, grown to 32 GB like a bigger USB drive, with empty UEFI variables like a new PC. The comments at the top of the script list its settings.

`scripts/nixsapos-tests.sh` checks a booted drive after its first boot: the partitions, mounts, services, kernel parameters, and an offline rebuild of `/etc/nixos`. It knows the differences between the minimal and secure images. It prints one PASS or FAIL line per check. Its exit code is the number of failed checks. `nix flake check` already covers the configuration itself, so the script only checks what shows at runtime.

Run it on the drive itself with `sudo scripts/nixsapos-tests.sh`, or from another computer over SSH:

```
$ go-task test HOST=nixsap@<IP_ADDRESS>
```

sshd is installed but does not start by default. Start it on the drive first with `sudo systemctl start sshd`. The virtual machine forwards port 2222 on this computer to its SSH port:

```
$ go-task test HOST=nixsap@localhost SSH_PORT=2222
```

### NixOS Tests

`checks/containers.nix` has NixOS tests (`pkgs.testers.runNixOSTest`). Each one starts nixsapOS in a systemd-nspawn container and runs a Python test script against it. There is one test for the profile and one for each feature module and `selection` level. Each checks the commands, services and generated files of its level, and that the commands of higher levels are missing. Run all of them, or one, in the builder container:

```
$ go-task test:nixos
```
```
$ go-task test:nixos TEST=container-profile-minimal
```

`checks/vms.nix` has the tests that need their own kernel, udev and drives. They start a QEMU virtual machine and need KVM. GitHub Actions runners have no KVM on free accounts. Run these tests locally. `vm-image-minimal` checks the kernel parameters, the I/O scheduler of extra NVMe, SATA and USB drives, the journal in RAM, `/tmp`, zram and the login screen. `vm-kernel-modules` checks that the Razer and Xbox controller drivers load at `unfree`. The virtual machine boots the kernel directly from a test drive. The image's boot loader, partitions and root file system are only checked by the image tests (see above).

The container runs with `--privileged` because the tests start their own containers and virtual machines. The builder container image has the Nix settings that they need: `auto-allocate-uids`, `cgroups` and `uid-range`.

A test passes once and is cached. It runs again after a change to anything that it uses. To run its commands by hand, open its Python shell, then run `start_all()` and commands such as `machine.succeed("id nixsap")`:

```
$ go-task test:nixos:interactive TEST=container-profile-minimal
```

Containers cannot run setuid programs such as `sudo`, mount file systems, or use hardware. The tests accept the services that fail for these reasons and list them in `container_failures`. For hardware daemons, the tests only check that they start at boot. The tests have no network. RetroDECK is installed from an offline stand-in for Flathub (`testFlathub`) with a tiny app of the same ID, so the test checks the Flatpak install itself. `scripts/nixsapos-tests.sh` checks the real RetroDECK on a booted drive with the `unfree` gaming applications. Boot, kernel, and storage settings need the image.

## GitHub Actions

Workflows are in `.github/workflows/`. They use the same builder container as local builds.

- `check.yml` runs `nix flake check --no-build` on every push and pull request. It evaluates every flake output and every check in `checks/`. It builds neither the image nor the NixOS tests. Run the same check locally with `go-task check`.
- `image.yml` builds both images, minimal and secure, with the same `docker run` command as a local build, on every push that changes more than Markdown files. It builds them one after the other. It checks that the images build. It does not upload them.

### Testing Workflows Locally

[act](https://github.com/nektos/act) runs GitHub Actions workflows in containers on your own computer. `go-task act:check` and `go-task act:build` run the commands below. To run them manually, get act from the nixpkgs version pinned in `flake.lock`, and point it at the Podman API socket:

```
act="$(nix --extra-experimental-features 'nix-command flakes' build --no-link --print-out-paths --inputs-from "git+file://$(pwd)" nixpkgs#act)"
systemctl --user start podman.socket
DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock" "${act}/bin/act" push --job check -P ubuntu-24.04=ghcr.io/catthehacker/ubuntu:act-24.04
systemctl --user stop podman.socket
```

- `-P` picks the container image for the `ubuntu-24.04` runner. The `catthehacker` images are made for act and include the Docker CLI, which the workflow uses to talk to Podman through the socket.
- act tests the files in your working directory, including changes that are not committed.
- The first run downloads about 2 GB of container images and takes about 3 minutes.

The image workflow needs a privileged container. It uses the rootful Podman socket and runs act as root. `--bind` mounts the repository into act's container instead of copying it, because the build container is started next to act's container and mounts host paths:

```
sudo systemctl start podman.socket
sudo DOCKER_HOST="unix:///run/podman/podman.sock" "${act}/bin/act" push --job build --bind -P ubuntu-24.04=ghcr.io/catthehacker/ubuntu:act-24.04
sudo systemctl stop podman.socket
```

- The images are written to `nixsapos-output/` next to the repository (`../nixsapos-output/`), the same place as on GitHub. Both use the rootful `nixsapos-nix` cache volume.
- act sets the `ACT` environment variable. The image workflow uses it to skip freeing disk space, which only makes sense on GitHub (act mounts its own tool cache).
