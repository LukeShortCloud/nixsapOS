{ pkgs }:

# An offline stand-in for Flathub, because the tests have no network.
# It has a tiny "net.retrodeck.retrodeck" app and the runtime that it needs.
# The real RetroDECK download is checked on a booted drive by scripts/nixsapos-tests.sh.
pkgs.runCommand "test-flathub" { nativeBuildInputs = [ pkgs.flatpak ]; } ''
  export HOME="$TMPDIR"
  # An app has its files in files/. A runtime has them in usr/, but flatpak also needs files/ to exist.
  mkdir -p "$out" runtime/files runtime/usr app/files/bin
  cat > runtime/metadata <<EOF
  [Runtime]
  name=org.nixsapos.TestPlatform
  runtime=org.nixsapos.TestPlatform/x86_64/stable
  sdk=org.nixsapos.TestPlatform/x86_64/stable
  EOF
  flatpak build-export --runtime "$out/repo" runtime stable

  cat > app/metadata <<EOF
  [Application]
  name=net.retrodeck.retrodeck
  runtime=org.nixsapos.TestPlatform/x86_64/stable
  sdk=org.nixsapos.TestPlatform/x86_64/stable
  command=retrodeck
  EOF
  printf '#!/bin/sh\necho RetroDECK\n' > app/files/bin/retrodeck
  chmod +x app/files/bin/retrodeck
  flatpak build-finish app
  flatpak build-export "$out/repo" app stable

  flatpak build-update-repo "$out/repo"
  cat > "$out/flathub.flatpakrepo" <<EOF
  [Flatpak Repo]
  Title=Flathub (test)
  Url=file://$out/repo/
  EOF
''
