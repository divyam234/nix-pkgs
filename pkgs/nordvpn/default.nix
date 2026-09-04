{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  copyDesktopItems,
  e2fsprogs,
  iproute2,
  libxslt,
  nftables,
  procps,
  systemdMinimal,
  wireguard-tools,
  openvpn,
}:
let
  version = "5.3.0";

  sources = {
    x86_64-linux = {
      asset = "nordvpn-v${version}-linux-amd64.tar.gz";
      hash = "sha256-Qf2VQ7jT/QSoj0iXxAktGBwIHpW2GyP1BJIwFAiq0CM=";
      dir = "nordvpn-v${version}-linux-amd64";
    };

    aarch64-linux = {
      asset = "nordvpn-v${version}-linux-arm64.tar.gz";
      hash = "sha256-mcBEfYhw4g5HpkpknU76cNxriWt1FKKkwdIvlBP3Ajg=";
      dir = "nordvpn-v${version}-linux-arm64";
    };
  };

  source = sources.${stdenv.hostPlatform.system} or (throw "nordvpn is not packaged for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "nordvpn";
  inherit version;

  src = fetchurl {
    url = "https://github.com/divyam234/nix-pkgs/releases/download/nordvpn-v${version}/${source.asset}";
    inherit (source) hash;
  };

  sourceRoot = source.dir;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = [ ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share

    # binaries from prebuilt tar
    install -Dm755 bin/nordvpn $out/bin/nordvpn
    install -Dm755 bin/nordvpnd $out/bin/nordvpnd
    install -Dm755 bin/norduserd $out/bin/norduserd 2>/dev/null || true

    # icons if present
    if [ -d share/icons ]; then
      cp -r share/icons $out/share/
    fi
    if [ -f assets/icon.svg ]; then
      install -Dm444 assets/icon.svg $out/share/icons/hicolor/scalable/apps/nordvpn.svg
    fi

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/nordvpnd --prefix PATH : ${
      lib.makeBinPath [
        e2fsprogs
        iproute2
        libxslt
        nftables
        openvpn
        procps
        systemdMinimal
        wireguard-tools
      ]
    }
  '';

  meta = {
    description = "NordVPN command-line client and daemon for Linux (prebuilt)";
    homepage = "https://github.com/NordSecurity/nordvpn-linux";
    changelog = "https://github.com/NordSecurity/nordvpn-linux/releases/tag/${version}";
    license = lib.licenses.gpl3Only;
    maintainers = [ ];
    platforms = lib.platforms.linux;
    mainProgram = "nordvpn";
  };
}
