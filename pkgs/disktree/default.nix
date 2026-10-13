{
  lib,
  stdenvNoCC,
  fetchurl,
  gpuiApp,
  git,
  trash-cli,
  xdg-utils,
}:

let
  version = "0.11.0";

  sources = {
    x86_64-linux = {
      asset = "disktree-0.11.0-x86_64-linux.tar.gz";
      hash = "sha256-fnWvoig8i0+SkNUurb/ADZ8UwTrtLSJMzfD3gm/MBbI=";
    };

    aarch64-linux = {
      asset = "disktree-0.11.0-aarch64-linux.tar.gz";
      hash = "sha256-PHX5yCBp5AMQyCE1elKu4vEanD4rRUUsmJPb98teRUo=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system} or (throw "disktree is not packaged for ${stdenvNoCC.hostPlatform.system}");
in
gpuiApp {
  pname = "disktree";
  inherit version;

  src = fetchurl {
    url = "https://github.com/tobi/disktree/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  sourceRoot = lib.removeSuffix ".tar.gz" source.asset;
  dontConfigure = true;
  dontBuild = true;
  binaryPath = "bin/disktree";
  extraWrapperArgs = [ "--suffix" "PATH" ":" (lib.makeBinPath [ git trash-cli xdg-utils ]) ];

  installPhase = ''
    runHook preInstall

    install -Dm755 disktree $out/bin/disktree
    install -Dm644 disktree.svg $out/share/icons/hicolor/scalable/apps/disktree.svg
    install -Dm644 disktree.desktop.in $out/share/applications/disktree.desktop
    substituteInPlace $out/share/applications/disktree.desktop \
      --replace-fail '@BINDIR@' "$out/bin" \
      --replace-fail '@VERSION@' '${version}'

    runHook postInstall
  '';

  meta = {
    description = "Disk space treemap for finding and removing what fills your disk";
    homepage = "https://github.com/tobi/disktree";
    license = lib.licenses.mit;
    mainProgram = "disktree";
    platforms = builtins.attrNames sources;
  };
}
