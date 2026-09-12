{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "ci-20260602-100737-UTC";

  sources = {
    x86_64-linux = {
      asset = "aria2-static-linux-x86_64.tar.gz";
      hash = "sha256-2Ju1RCF1jrFRtL3Fhfh5Wb3El9dKRtFZGVT/fzUvrmY=";
    };

    aarch64-linux = {
      asset = "aria2-static-linux-arm64.tar.gz";
      hash = "sha256-Sy3a7JlVDgXq7hwAWFVetsjZvcTEnUdGvUt8L8XHLUA=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system} or (throw "aria2 is not packaged for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "aria2-pro-core";
  inherit version;

  src = fetchurl {
    url = "https://github.com/antman666/Aria2-Pro-Core/releases/download/${version}/${source.asset}";
    inherit (source) hash;
  };

  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 aria2c "$out/bin/aria2c"
    runHook postInstall
  '';

  meta = {
    description = "Aria2 static binary with enhanced feature patches";
    homepage = "https://github.com/antman666/Aria2-Pro-Core";
    license = lib.licenses.gpl3Plus;
    maintainers = [ ];
    mainProgram = "aria2c";
    platforms = builtins.attrNames sources;
  };
}
