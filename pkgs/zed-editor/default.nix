{
  lib,
  stdenvNoCC,
  fetchurl,
  gpuiApp,
  nodejs,
  alsa-lib,
}:

let
  version = "1.24.2";

  sources = {
    x86_64-linux = {
      asset = "zed-linux-x86_64.tar.gz";
      hash = "sha256-Ago7Aqn0u14AFbrXzGRCYr9OoyzX729/RpGUbUOvD4k=";
    };

    aarch64-linux = {
      asset = "zed-linux-aarch64.tar.gz";
      hash = "sha256-lqVIBqfihkUgeL38lLY8e/a4Mk/8sWxcYP8f2WdD6kU=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system} or (throw "zed-editor is not packaged for ${stdenvNoCC.hostPlatform.system}");

in
gpuiApp {
  pname = "zed-editor";
  inherit version;

  src = fetchurl {
    url = "https://github.com/zed-industries/zed/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  sourceRoot = "zed.app";

  binaryPath = "libexec/zed-editor";
  extraWrapperArgs = [ "--suffix" "PATH" ":" (lib.makeBinPath [ nodejs ]) ];
  buildInputs = [ alsa-lib ];

  installPhase = ''
    runHook preInstall

    install -Dm755 libexec/zed-editor $out/libexec/zed-editor
    install -Dm755 bin/zed $out/bin/zed

    install -Dm644 share/icons/hicolor/1024x1024/apps/zed.png $out/share/icons/hicolor/512x512@2/apps/zed.png
    install -Dm644 share/icons/hicolor/512x512/apps/zed.png $out/share/icons/hicolor/512x512/apps/zed.png

    install -Dm644 share/applications/dev.zed.Zed.desktop $out/share/applications/dev.zed.Zed.desktop

    mkdir -p $out/lib
    cp -r lib/* $out/lib/

    runHook postInstall
  '';


  meta = {
    description = "High-performance, multiplayer code editor from the creators of Atom and Tree-sitter";
    homepage = "https://zed.dev";
    license = lib.licenses.gpl3Only;
    maintainers = [ ];
    mainProgram = "zed";
    platforms = builtins.attrNames sources;
  };
}
