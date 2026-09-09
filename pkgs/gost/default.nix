{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "3.3.0";

  sources = {
    x86_64-linux = {
      asset = "gost_3.3.0_linux_amd64.tar.gz";
      hash = "sha256-Z2+3940me2rnPfcZwMfytWXd5xR9qTXPr7weHaVYttU=";
    };

    aarch64-linux = {
      asset = "gost_3.3.0_linux_arm64.tar.gz";
      hash = "sha256-0DaZ4/OF1P9drWgEZxKt/MdRUyWgZNKrBG4L7OMPj48=";
    };
  };

  source = sources.${stdenv.hostPlatform.system} or (throw "gost is not packaged for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "gost";
  inherit version;

  src = fetchurl {
    url = "https://github.com/go-gost/gost/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 gost "$out/bin/gost"
    runHook postInstall
  '';

  meta = {
    description = "GO Simple Tunnel - a simple tunnel written in Golang";
    homepage = "https://github.com/go-gost/gost";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "gost";
    platforms = builtins.attrNames sources;
  };
}
