{
  lib,
  stdenvNoCC,
  fetchurl,
  gpuiApp,
  glib,
  zenity,
  python3,
}:

let
  version = "0.8.4";

  # Only x86_64-linux: the startup login flow is removed by patching the
  # binary (see scripts/patch-tern-gate.py), and the patch fingerprints
  # currently cover the x86_64 build only.
  sources = {
    x86_64-linux = {
      asset = "Tern-0.8.4-linux-x86_64.tar.gz";
      hash = "sha256-anF15qGBMke33G9n4cqdUcJcyCNX5VJgHH+/jeuge+8=";
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

  nativeBuildInputs = [ python3 ];

  installPhase = ''
    runHook preInstall

    install -Dm755 tern/tern "$out/bin/tern"

    # Remove the remote startup login flow (closed-beta gate, keychain
    # lookup, sign-in veil). Fails the build if the fingerprints no
    # longer match, so an upstream codegen change can never ship
    # unpatched silently.
    python3 ${../../scripts/patch-tern-gate.py} "$out/bin/tern"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    "$out/bin/tern" --version
  '';

  meta = {
    description = "AI-native terminal with persistent sessions";
    homepage = "https://stencil.so";
    mainProgram = "tern";
    platforms = [ "x86_64-linux" ];
  };
}
