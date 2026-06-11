{
  lib,
  autoPatchelfHook,
  gcc-unwrapped,
  githubReleaseBinary,
  makeBinaryWrapper,
  ripgrep,
}:

let
  version = "1.17.3";

  sources = {
    x86_64-linux = {
      asset = "opencode-linux-x64.tar.gz";
      hash = "sha256-1L0jiiwf9WrKHNM5fSGgoxf1mSI0UXp/jir7vXIBCn0=";
    };

    aarch64-linux = {
      asset = "opencode-linux-arm64.tar.gz";
      hash = "sha256-hhuMZs7VHW2aZup3POR+3mY6RL0X2De5whrPo0aIAeU=";
    };
  };
in
githubReleaseBinary {
  inherit version sources;
  pname = "opencode";
  owner = "anomalyco";
  repo = "opencode";

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];

  buildInputs = [
    gcc-unwrapped.lib
  ];

  postInstall = ''
    wrapProgram "$out/bin/opencode" \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}
  '';

  passthru.runtimeInputs = [
    ripgrep
  ];

  meta = {
    description = "AI coding agent, built for the terminal";
    homepage = "https://github.com/anomalyco/opencode";
    license = lib.licenses.mit;
    maintainers = [ ];
  };
}
