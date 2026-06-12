{
  lib,
  autoPatchelfHook,
  gcc-unwrapped,
  githubReleaseBinary,
  makeBinaryWrapper,
  ripgrep,
}:

let
  version = "1.17.4";

  sources = {
    x86_64-linux = {
      asset = "opencode-linux-x64.tar.gz";
      hash = "sha256-ouzpGBqrOBemtZ+jkLbUWbGH4+yRe+gC7Lyoi2MsXvk=";
    };

    aarch64-linux = {
      asset = "opencode-linux-arm64.tar.gz";
      hash = "sha256-XLMtUyOKIFpK1x9wvo1mmq9GD1USHrwW/50SkJYJ3Qs=";
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
