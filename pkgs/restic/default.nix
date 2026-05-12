{
  lib,
  stdenv,
  fetchurl,
  bzip2,
}:

let
  version = "0.18.1";

  sources = {
    x86_64-linux = {
      asset = "restic_${version}_linux_amd64.bz2";
      hash = "sha256-aAg48Z1nFRrboifhVwzdivEsGc8XNXg+0bqSi8QfNj0=";
    };

    aarch64-linux = {
      asset = "restic_${version}_linux_arm64.bz2";
      hash = "sha256-h/U/3d44dkCV6cBYo7MYNAUsN+WCbSrPNOGJI8AGvUU=";
    };
  };

  source = sources.${stdenv.hostPlatform.system} or (throw "restic is not packaged for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "restic";
  inherit version;

  src = fetchurl {
    url = "https://github.com/restic/restic/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  nativeBuildInputs = [
    bzip2
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    bzip2 -d < "$src" > restic
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 restic "$out/bin/restic"

    runHook postInstall
  '';

  meta = {
    description = "Fast, secure, efficient backup program";
    homepage = "https://restic.net";
    license = lib.licenses.bsd2;
    maintainers = [ ];
    mainProgram = "restic";
    platforms = builtins.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
