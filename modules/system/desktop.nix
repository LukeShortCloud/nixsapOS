{ ... }:

{
  # Disable KWallet for every user. Otherwise it asks for a password to unlock it after logging in.
  environment.etc."xdg/kwalletrc".text = ''
    [Wallet]
    Enabled=false
  '';
}
