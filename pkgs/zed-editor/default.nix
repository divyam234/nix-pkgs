{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  nodejs,
  alsa-lib,
  libdrm,
  libGL,
  libglvnd,
  libxkbcommon,
  stdenv,
  vulkan-loader,
  wayland,
  xkeyboard_config,
}:

let
  version = "1.7.2";

  sources = {
    x86_64-linux = {
      asset = "zed-linux-x86_64.tar.gz";
      hash = "sha256-udaYeTTCoDgz9fGWUI8Vq4ho1COW3Bp2Bxhq1w1unAI=";
    };

    aarch64-linux = {
      asset = "zed-linux-aarch64.tar.gz";
      hash = "sha256-KFTis3V+1lILS4+U7HlCbI7CHv0kRMi+/zP0CMkKikg=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system} or (throw "zed-editor is not packaged for ${stdenvNoCC.hostPlatform.system}");

  runtimeLibs = lib.makeLibraryPath [
    alsa-lib
    libdrm
    libGL
    libglvnd
    libxkbcommon
    stdenv.cc.cc.lib
    vulkan-loader
    wayland
  ];
in
stdenvNoCC.mkDerivation {
  pname = "zed-editor";
  inherit version;

  src = fetchurl {
    url = "https://github.com/zed-industries/zed/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  sourceRoot = "zed.app";

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];

  buildInputs = [
    alsa-lib
    libdrm
    libGL
    libglvnd
    libxkbcommon
    stdenv.cc.cc.lib
    vulkan-loader
    wayland
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 libexec/zed-editor $out/libexec/zed-editor
    install -Dm755 bin/zed $out/bin/zeditor

    install -Dm644 share/icons/hicolor/1024x1024/apps/zed.png $out/share/icons/hicolor/512x512@2/apps/zed.png
    install -Dm644 share/icons/hicolor/512x512/apps/zed.png $out/share/icons/hicolor/512x512/apps/zed.png

    install -Dm644 share/applications/dev.zed.Zed.desktop $out/share/applications/dev.zed.Zed.desktop
    substituteInPlace $out/share/applications/dev.zed.Zed.desktop \
      --replace-fail "TryExec=zed" "TryExec=zeditor" \
      --replace-fail "Exec=zed %U" "Exec=zeditor %U" \
      --replace-fail "Exec=zed --new" "Exec=zeditor --new"

    mkdir -p $out/lib
    cp -r lib/* $out/lib/

    runHook postInstall
  '';

  postFixup = ''
    patchelf $out/libexec/zed-editor --add-rpath ${runtimeLibs}
    wrapProgram $out/libexec/zed-editor \
      --suffix PATH : ${lib.makeBinPath [ nodejs ]} \
      --prefix LD_LIBRARY_PATH : ${runtimeLibs} \
      --set-default XKB_CONFIG_ROOT "${xkeyboard_config}/share/X11/xkb"
  '';

  meta = {
    description = "High-performance, multiplayer code editor from the creators of Atom and Tree-sitter";
    homepage = "https://zed.dev";
    license = lib.licenses.gpl3Only;
    maintainers = [ ];
    mainProgram = "zeditor";
    platforms = builtins.attrNames sources;
  };
}
