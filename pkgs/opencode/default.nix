{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  gcc-unwrapped,
  makeBinaryWrapper,
  ripgrep,
}:

let
  version = "2.0.18";

  sources = {
    x86_64-linux = {
      asset = "opencode-linux-x64.tar.gz";
      hash = "sha256-YiV+e38iCDrt4+TGa4BXzs8KcDiEYxK4Ya/JkQ43k14=";
    };

    aarch64-linux = {
      asset = "opencode-linux-arm64.tar.gz";
      hash = "sha256-9GJT8P9e/wwXUdO3NO3lXMYNky1gr4HQYdA3RfmZgII=";
    };
  };

  source = sources.${stdenv.hostPlatform.system} or (throw "opencode is not packaged for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "opencode";
  inherit version;

  src = fetchurl {
    url = "https://opencode.ai/files/bin/${version}/${source.asset}";
    inherit (source) hash;
  };

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  # files.bin tarballs contain a single flat `opencode` binary (no
  # directory), which trips the generic unpacker's directory check.
  unpackPhase = ''
    runHook preUnpack

    tar -xzf "$src"

    runHook postUnpack
  '';

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];

  buildInputs = [
    gcc-unwrapped.lib
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 opencode "$out/bin/opencode"

    wrapProgram "$out/bin/opencode" \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}

    runHook postInstall
  '';

  passthru.runtimeInputs = [
    ripgrep
  ];

  meta = {
    description = "AI coding agent, built for the terminal";
    homepage = "https://opencode.ai";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "opencode";
    platforms = builtins.attrNames sources;
  };
}
