{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  gcc-unwrapped,
}:

let
  version = "8.1-latest-2026-05-08";
  downloadTag = "autobuild-2026-05-08-13-23";

  sources = {
    x86_64-linux = {
      asset = "ffmpeg-n8.1.1-linux64-gpl-shared-8.1.tar.xz";
      hash = "sha256-+h/QOycsDv6HQ5ZL41wniUqx4WWDIs++yqic7TsFgXQ=";
    };

    aarch64-linux = {
      asset = "ffmpeg-n8.1.1-linuxarm64-gpl-shared-8.1.tar.xz";
      hash = "sha256-1ZotFoUeNX36zVhd5CVgcmeEPjNc/Ym6lm5d1MuIq50=";
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
