{
  lib,
  stdenvNoCC,
  fetchurl,
  gpuiApp,
  glib,
  zenity,
}:

let
  version = "0.8.4";

  sources = {
    x86_64-linux = {
      asset = "Tern-0.8.4-linux-x86_64.tar.gz";
      hash = "sha256-anF15qGBMke33G9n4cqdUcJcyCNX5VJgHH+/jeuge+8=";
    };
    aarch64-linux = {
      asset = "Tern-0.8.4-linux-arm64.tar.gz";
      hash = "sha256-cgZAtZCuzAdjcW0e8q8CYvLtn1tkb7p/VOBllKYOQ9g=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system} or (throw "tern is not packaged for ${stdenvNoCC.hostPlatform.system}");
in
gpuiApp {
  pname = "tern";
  inherit version;

  src = fetchurl {
    url = "https://github.com/divyam234/nix-pkgs/releases/download/tern-v${version}/${source.asset}";
    inherit (source) hash;
  };

  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  binaryPath = "bin/tern";
  extraWrapperArgs = [
    "--prefix" "PATH" ":" (lib.makeBinPath [ glib.bin zenity ])
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 tern/tern "$out/bin/tern"

    runHook postInstall
  '';

  meta = {
    description = "AI-native terminal with persistent sessions";
    homepage = "https://stencil.so";
    mainProgram = "tern";
    platforms = builtins.attrNames sources;
  };
}
