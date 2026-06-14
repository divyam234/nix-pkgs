{ lib, fetchurl, stdenvNoCC }:

let
  version = "0.23.0";
in
stdenvNoCC.mkDerivation {
  pname = "zjstatus";
  inherit version;

  src = fetchurl {
    url = "https://github.com/dj95/zjstatus/releases/download/v${version}/zjstatus.wasm";
    hash = "sha256-4AaQEiNSQjnbYYAh5MxdF/gtxL+uVDKJW6QfA/E4Yf8=";
  };

  srcZjframes = fetchurl {
    url = "https://github.com/dj95/zjstatus/releases/download/v${version}/zjframes.wasm";
    hash = "sha256-jYnoMb3hlTY/qlqBCwRGCkIQBtN8mIbOniVRMPqToIU=";
  };

  dontUnpack = true;
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 $src $out/bin/zjstatus.wasm
    install -Dm644 $srcZjframes $out/bin/zjframes.wasm
    runHook postInstall
  '';

  meta = {
    description = "A configurable statusbar plugin for zellij";
    homepage = "https://github.com/dj95/zjstatus";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
