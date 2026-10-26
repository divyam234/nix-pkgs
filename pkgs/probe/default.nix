{
  lib,
  stdenvNoCC,
  fetchurl,
  gpuiApp,
}:

let
  version = "2.1.1";

  sources = {
    x86_64-linux = {
      asset = "probe-desktop-2.1.1-linux-x64.tar.gz";
      hash = "sha256-fW65YN04ZTxV8pL39K3A4+lFlvSpeRqNUx9gv0bQqTA=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system} or (throw "probe is not packaged for ${stdenvNoCC.hostPlatform.system}");
in
gpuiApp {
  pname = "probe";
  inherit version;

  src = fetchurl {
    url = "https://github.com/crizant/probe/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  binaryPath = "bin/probe-desktop";

  installPhase = ''
    runHook preInstall

    install -Dm755 probe-desktop $out/bin/probe-desktop
    mkdir -p $out/share
    cp -r share/icons share/applications $out/share/
    substituteInPlace $out/share/applications/dev.probe.desktop.desktop \
      --replace-fail 'Exec=probe-desktop' "Exec=$out/bin/probe-desktop"

    runHook postInstall
  '';

  meta = {
    description = "Fast, native, local-first API client";
    homepage = "https://github.com/crizant/probe";
    license = lib.licenses.asl20;
    mainProgram = "probe-desktop";
    platforms = builtins.attrNames sources;
  };
}
