{
  lib,
  githubReleaseBinary,
}:

let
  version = "1.8.3";

  sources = {
    x86_64-linux = {
      asset = "teldrive-${version}-linux-amd64.tar.gz";
      hash = "sha256-QRQ2LJvtrVnfHwFkLXJo3HO2OsLdmXCpV8fQwOpw0KQ=";
    };

    aarch64-linux = {
      asset = "teldrive-${version}-linux-arm64.tar.gz";
      hash = "sha256-7HhGNEe1YxRA8HF0mloqI5gxYHPELj+TmxRCA4HR784=";
    };
  };
in
githubReleaseBinary {
  inherit version sources;
  pname = "teldrive";
  owner = "tgdrive";
  repo = "teldrive";
  downloadTag = version;

  binaryName = "teldrive";

  meta = {
    description = "Self-hosted Telegram drive server";
    homepage = "https://github.com/tgdrive/teldrive";
    license = lib.licenses.mit;
    maintainers = [ ];
  };
}
