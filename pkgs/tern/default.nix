{
  lib,
  stdenvNoCC,
  fetchurl,
  gpuiApp,
  glib,
  zenity,
}:

let
  version = "0.9.5";

  # Only x86_64-linux: release preparation patches the startup login flow
  # (see scripts/patch-tern-gate.py), and the patch fingerprints
  # currently cover the x86_64 build only.
  sources = {
    x86_64-linux = {
      asset = "Tern-0.9.5-linux-x86_64.tar.gz";
      hash = "sha256-+IqPOprsO9kiAZKsIclGFkKzhX97RMkQFGxVdesEZwU=";
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
    # Never phone home: the closed beta gate is patched out and omp
    # management is disabled via state, so the auth and build services
    # are unreachable by design. Pointing them at a dead address makes
    # any residual check fail fast instead of hitting the network.
    # --set-default keeps them overridable via the environment.
    "--set-default" "TERN_AUTH_URL" "http://127.0.0.1:9"
    "--set-default" "TERN_BUILD_URL" "http://127.0.0.1:9"
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 tern/tern "$out/bin/tern"

    install -Dm644 ${./tern.desktop} "$out/share/applications/tern.desktop"
    substituteInPlace "$out/share/applications/tern.desktop" \
      --replace-fail 'Exec=tern' "Exec=$out/bin/tern"
    install -Dm644 ${./tern.png} \
      "$out/share/icons/hicolor/512x512/apps/tern.png"

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
