{
  lib,
  autoPatchelfHook,
  gcc-unwrapped,
  githubReleaseBinary,
  makeBinaryWrapper,
  ripgrep,
}:

let
  version = "1.15.6";

  sources = {
    x86_64-linux = {
      asset = "opencode-linux-x64.tar.gz";
      hash = "sha256-mHTQhX97AaCRieu4r0LvINVWvj8NBUVj5e7xI0Uoxx8=";
    };

    aarch64-linux = {
      asset = "opencode-linux-arm64.tar.gz";
      hash = "sha256-xEN7JxLtloN8sGtEiwTT0g9+8QBzWwatMZq3ntARGSs=";
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
