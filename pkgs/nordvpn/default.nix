{
  callPackage,
  fetchFromGitHub,
  lib,
  nix-update-script,
  symlinkJoin,
}:
let
  version = "5.1.0";

  common = {
    inherit version;

    src = fetchFromGitHub {
      owner = "NordSecurity";
      repo = "nordvpn-linux";
      tag = version;
      hash = "sha256-I0PBv2EBfy8oCtYBIalUwfLESa3Od5yvl/Gj96za+60=";
    };

    # rec so that changelog can reference homepage
    meta = rec {
      homepage = "https://github.com/NordSecurity/nordvpn-linux";
      changelog = "${homepage}/releases/tag/${version}";
      license = lib.licenses.gpl3Only;
      maintainers = [ ];
      platforms = lib.platforms.linux;
    };

    desktopItemArgs = {
      categories = [ "Network" ];
      genericName = "VPN Client";
      icon = "nordvpn";
      type = "Application";
    };
  };

  cli = callPackage ./cli.nix common;
in
symlinkJoin {
  pname = "nordvpn";
  inherit version;

  strictDeps = true;
  __structuredAttrs = true;

  paths = [ cli ];

  passthru = {
    inherit cli;
    updateScript = nix-update-script { };
  };

  meta = common.meta // {
    description = "NordVPN command-line client and daemon for Linux";
    longDescription = ''
      NordVPN CLI application and daemon for Linux.
      This package currently does not support meshnet.
      Additionally, if `networking.firewall.enable = true;`,
      then also set `networking.firewall.checkReversePath = "loose";`.
      The closed-source nordwhisper protocol is also not supported.
    '';
    mainProgram = "nordvpn";
  };
}
