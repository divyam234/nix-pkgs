{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  libxkbcommon,
  libxcb,
}:

let
  version = "0.6.18";

  sources = {
    x86_64-linux = {
      asset = "openlogi-v${version}-linux-amd64.deb";
      hash = "sha256-Q30YWMEv3U7UZLeg2qk4NVx430Shln8tRyMi9qdZ5DA=";
    };

    aarch64-linux = {
      asset = "openlogi-v${version}-linux-arm64.deb";
      hash = "sha256-xbb8PSep0xui/lY61knTsWqn0elQOEXU5BnTTQVHX9A=";
    };
  };

  source = sources.${stdenv.hostPlatform.system} or (throw "openlogi is not packaged for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "openlogi";
  inherit version;

  src = fetchurl {
    url = "https://github.com/AprilNEA/OpenLogi/releases/download/v${version}/${source.asset}";
    hash = source.hash;
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    libxkbcommon
    libxcb
    stdenv.cc.cc.lib
  ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    ar x $src
    tar xf data.tar.gz

    install -Dm755 usr/bin/* -t $out/bin/

    install -Dm644 usr/share/applications/openlogi.desktop \
      $out/share/applications/openlogi.desktop

    install -Dm644 usr/share/icons/hicolor/512x512/apps/openlogi.png \
      $out/share/icons/hicolor/512x512/apps/openlogi.png

    install -Dm644 etc/udev/rules.d/70-openlogi.rules \
      $out/lib/udev/rules.d/70-openlogi.rules

    mkdir -p $out/lib/systemd/user
    sed "s|@BINDIR@|$out/bin|g" \
      usr/lib/systemd/user/openlogi-agent.service \
      > $out/lib/systemd/user/openlogi-agent.service

    runHook postInstall
  '';

  meta = {
    description = "A native, local-first alternative to Logitech Options+, written in Rust";
    homepage = "https://github.com/AprilNEA/OpenLogi";
    license = with lib.licenses; [ mit asl20 ];
    maintainers = [ ];
    platforms = builtins.attrNames sources;
    mainProgram = "openlogi";
  };
}
