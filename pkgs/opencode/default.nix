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
  version = "2.0.16";

  sources = {
    x86_64-linux = {
      asset = "opencode-linux-x64.tar.gz";
      hash = "sha256-K5zaM6elOH68XTfaR4uny5BSSnaXQa/aTETObNLCgWM=";
    };

    aarch64-linux = {
      asset = "opencode-linux-arm64.tar.gz";
      hash = "sha256-TVn3CfuGesBLI7imOY06fdBeeWmUrv4Hy5lQcYZetKY=";
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
