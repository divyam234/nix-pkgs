{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  libxkbcommon,
  libxcb,
  wayland,
  libglvnd,
  vulkan-loader,
  libdrm,
}:

let
  version = "0.6.23";

  sources = {
    x86_64-linux = {
      asset = "openlogi-v0.6.23-linux-amd64.deb";
      hash = "sha256-jsKthRikrpqshgqwWf26zSZ696edTNvszc7rzxVDjV4=";
    };

    aarch64-linux = {
      asset = "openlogi-v0.6.23-linux-arm64.deb";
      hash = "sha256-gLg6XcQQvKZdlLrIcfjOE/9u1Cq8MSheX1nfXDMnrWg=";
    };
  };

  source = sources.${stdenv.hostPlatform.system} or (throw "openlogi is not packaged for ${stdenv.hostPlatform.system}");

  runtimeLibs = lib.makeLibraryPath [
    libdrm
    libglvnd
    libxkbcommon
    libxcb
    stdenv.cc.cc.lib
    vulkan-loader
    wayland
  ];
in
stdenv.mkDerivation {
  pname = "openlogi";
  inherit version;

  src = fetchurl {
    url = "https://github.com/AprilNEA/OpenLogi/releases/download/v${version}/${source.asset}";
    hash = source.hash;
  };

  nativeBuildInputs = [ autoPatchelfHook makeBinaryWrapper ];

  buildInputs = [
    libdrm
    libglvnd
    libxkbcommon
    libxcb
    stdenv.cc.cc.lib
    vulkan-loader
    wayland
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

  preFixup = ''
    patchelf $out/bin/openlogi-gui --add-rpath ${runtimeLibs}
  '';

  postFixup = ''
    wrapProgram $out/bin/openlogi-gui \
      --prefix LD_LIBRARY_PATH : ${runtimeLibs}
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
