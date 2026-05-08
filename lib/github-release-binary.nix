{
  lib,
  stdenv,
  fetchurl,
}:

{
  pname,
  version,
  owner,
  repo,
  sources,
  downloadTag ? "v${version}",
  binaryName ? pname,
  installName ? binaryName,
  nativeBuildInputs ? [ ],
  buildInputs ? [ ],
  postInstall ? "",
  sourceRoot ? ".",
  passthru ? { },
  meta ? { },
}:

let
  source = sources.${stdenv.hostPlatform.system} or (throw "${pname} is not packaged for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  inherit pname version sourceRoot;

  src = fetchurl {
    url = "https://github.com/${owner}/${repo}/releases/download/${downloadTag}/${source.asset}";
    inherit (source) hash;
  };

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  inherit nativeBuildInputs;
  inherit buildInputs;
  inherit passthru;

  installPhase = ''
    runHook preInstall

    install -Dm755 ${binaryName} "$out/bin/${installName}"
    ${postInstall}

    runHook postInstall
  '';

  meta = {
    mainProgram = installName;
    platforms = builtins.attrNames sources;
  } // meta;
}
