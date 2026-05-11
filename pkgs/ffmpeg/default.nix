{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  gcc-unwrapped,
}:

let
  version = "8.1-latest-2026-05-10";
  downloadTag = "latest";

  sources = {
    x86_64-linux = {
      asset = "ffmpeg-n8.1-latest-linux64-gpl-shared-8.1.tar.xz";
      hash = "sha256-osfVbgUcR+rMHnPk1+5TCIZ1/TX/RL+Pl0se7lO9vwA=";
    };

    aarch64-linux = {
      asset = "ffmpeg-n8.1-latest-linuxarm64-gpl-shared-8.1.tar.xz";
      hash = "sha256-/hBjVFbtRuSs1cLzO4M2mFivEREXebBngHrePj38v3Q=";
    };
  };

  source = sources.${stdenv.hostPlatform.system} or (throw "ffmpeg is not packaged for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "ffmpeg";
  inherit version;

  src = fetchurl {
    url = "https://github.com/BtbN/FFmpeg-Builds/releases/download/${downloadTag}/${source.asset}";
    inherit (source) hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    gcc-unwrapped.lib
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R bin lib include man doc presets "$out/"

    runHook postInstall
  '';

  preFixup = ''
    addAutoPatchelfSearchPath "$out/lib"
  '';

  meta = {
    description = "FFmpeg 8.1 GPL shared build from BtbN";
    homepage = "https://github.com/BtbN/FFmpeg-Builds";
    license = lib.licenses.gpl3Plus;
    maintainers = [ ];
    mainProgram = "ffmpeg";
    platforms = builtins.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
