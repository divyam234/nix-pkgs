{ lib, stdenvNoCC, fetchurl, makeBinaryWrapper }:

let
  version = "9.4";

  sources = {
    x86_64-linux = {
      asset = "ida-pro_${version}_x64linux.run";
      hash = "sha256-7ByCvaphbsqyilC1VA9PbyYCrcIr0rS8if00BAO9sZo=";
    };
  };
in
stdenvNoCC.mkDerivation {
  pname = "ida-pro";
  inherit version;

  src = fetchurl {
    url = "https://github.com/divyam234/nix-pkgs/releases/download/ida-pro-${version}/${sources.${stdenvNoCC.hostPlatform.system}.asset}";
    hash = sources.${stdenvNoCC.hostPlatform.system}.hash;
  };

  nativeBuildInputs = [
    makeBinaryWrapper
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    sh "$src" --noexec --target "$PWD/ida"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt $out/bin
    cp -r ida/* $out/opt/ida-pro-${version}

    makeWrapper $out/opt/ida-pro-${version}/ida $out/bin/ida \
      --chdir $out/opt/ida-pro-${version}

    runHook postInstall
  '';

  meta = {
    description = "IDA Pro interactive disassembler";
    homepage = "https://hex-rays.com/";
    license = lib.licenses.unfree;
    maintainers = [ ];
    mainProgram = "ida";
    platforms = [ "x86_64-linux" ];
  };
}
