{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  dbus,
  fontconfig,
  libGL,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  libxrandr,
  libxkbcommon,
  vulkan-loader,
  wayland,
  xdg-utils,
  zenity,
}:

let
  version = "0.11.0";

  sources = {
    x86_64-linux = {
      asset = "pdfcraft-0.11.0-linux-x86_64.tar.gz";
      hash = "sha256-Da1dSyH8j9EZLouFTTjcwlf65mga4X8Q8bP0HoRIj08=";
    };

    aarch64-linux = {
      asset = "pdfcraft-0.11.0-linux-aarch64.tar.gz";
      hash = "sha256-TONz9aF/kKn5HtAZg7doO9/1RNGIIioPOt290XKaT7s=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system} or (throw "pdfcraft is not packaged for ${stdenvNoCC.hostPlatform.system}");
  runtimeLibs = [
    dbus
    fontconfig
    libGL
    libx11
    libxcb
    libxcursor
    libxi
    libxrandr
    libxkbcommon
    vulkan-loader
    wayland
    stdenv.cc.cc.lib
  ];
in
stdenvNoCC.mkDerivation {
  pname = "pdfcraft";
  inherit version;

  src = fetchurl {
    url = "https://github.com/storytold/pdfcraft/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  sourceRoot = lib.removeSuffix ".tar.gz" source.asset;
  dontConfigure = true;
  dontBuild = true;
  nativeBuildInputs = [ autoPatchelfHook makeBinaryWrapper ];
  buildInputs = runtimeLibs;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m755 bin/pdfcraft bin/pdfcraft-cli $out/bin/
    cp -r share $out/share
    substituteInPlace $out/share/applications/ai.storyteller.pdfcraft.desktop \
      --replace-fail 'Exec=pdfcraft %U' "Exec=$out/bin/pdfcraft %U" \
      --replace-fail 'TryExec=pdfcraft' "TryExec=$out/bin/pdfcraft"

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/pdfcraft \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils zenity ]}
  '';

  meta = {
    description = "Native PDF reader and editor with a command-line interface";
    homepage = "https://github.com/storytold/pdfcraft";
    license = with lib.licenses; [ mit asl20 ];
    mainProgram = "pdfcraft";
    platforms = builtins.attrNames sources;
  };
}
