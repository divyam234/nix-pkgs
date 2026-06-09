{
  lib,
  autoPatchelfHook,
  gcc-unwrapped,
  githubReleaseBinary,
  makeBinaryWrapper,
  ripgrep,
}:

let
  version = "1.16.2";

  sources = {
    x86_64-linux = {
      asset = "opencode-linux-x64.tar.gz";
      hash = "sha256-BqecW7f40BcWskQHEs9n+s0221kYiAmusjI3SyBr1Ck=";
    };

    aarch64-linux = {
      asset = "opencode-linux-arm64.tar.gz";
      hash = "sha256-6x1YdscGdc/ak8ShxDhdcnQS+ucxVPHwBdFVYm31tVk=";
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
