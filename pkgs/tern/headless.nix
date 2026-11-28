{
  stdenvNoCC,
  autoPatchelfHook,
  fetchurl,
  stdenv,
}:
stdenvNoCC.mkDerivation (
  (import ./source.nix { inherit fetchurl stdenvNoCC; })
  // {
    pname = "tern-headless";
    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ];
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 tern "$out/bin/tern"
      runHook postInstall
    '';

    meta = {
      description = "Headless Tern remote session server";
      homepage = "https://stencil.so";
      mainProgram = "tern";
      platforms = builtins.attrNames (import ./release.nix).sources;
    };
  }
)
