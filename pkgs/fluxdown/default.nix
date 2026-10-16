{
  lib,
  stdenvNoCC,
  fetchurl,
  gpuiApp,
  gtk3,
  libayatana-appindicator,
  wrapGAppsHook3,
}:

let
  version = "0.5.7";

  sources = {
    x86_64-linux = {
      asset = "FluxDown-0.5.7-linux-x64.tar.gz";
      hash = "sha256-nOrK4GBJWdVH8wZq8IWw4ZEyNWp5i5Nu0SBV+PpshK8=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system} or (throw "fluxdown is not packaged for ${stdenvNoCC.hostPlatform.system}");
in
gpuiApp {
  pname = "fluxdown";
  inherit version;

  src = fetchurl {
    url = "https://github.com/zerx-lab/FluxDown/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  sourceRoot = "FluxDown-${version}-linux-x64";
  dontConfigure = true;
  dontBuild = true;
  binaryPath = "bin/fluxdown-desktop";
  nativeBuildInputs = [ wrapGAppsHook3 ];
  buildInputs = [ gtk3 libayatana-appindicator ];

  installPhase = ''
    runHook preInstall

    for binary in fluxdown-desktop fluxdown-agent fluxdownd fluxdown_nmh; do
      install -Dm755 "$binary" "$out/bin/$binary"
    done
    install -Dm644 com.fluxdown.app.desktop $out/share/applications/com.fluxdown.app.desktop
    install -Dm644 com.fluxdown.app.png $out/share/pixmaps/com.fluxdown.app.png
    substituteInPlace $out/share/applications/com.fluxdown.app.desktop \
      --replace-fail 'Exec=fluxdown-desktop' "Exec=$out/bin/fluxdown-desktop"

    runHook postInstall
  '';

  meta = {
    description = "Native multi-protocol download manager";
    homepage = "https://github.com/zerx-lab/FluxDown";
    license = lib.licenses.agpl3Only;
    mainProgram = "fluxdown-desktop";
    platforms = builtins.attrNames sources;
  };
}
