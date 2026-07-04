{
  lib,
  stdenv,
  fetchurl,
  unzip,
}:

let
  version = "1.73.1";

  sources = {
    x86_64-linux = {
      asset = "rclone-v1.73.1-linux-amd64.zip";
      hash = "sha256-g5ZlR9iXl1bns3cGz9RQKf0NsdK2ISXpyT6F23sobEM=";
      dir = "rclone-v${version}-linux-amd64";
    };

    aarch64-linux = {
      asset = "rclone-v1.73.1-linux-arm64.zip";
      hash = "sha256-MkJe+ffEAPpsqUHYvZdNvES8Wwn7RL65zYZAJWrX4B4=";
      dir = "rclone-v${version}-linux-arm64";
    };
  };

  source = sources.${stdenv.hostPlatform.system} or (throw "rclone is not packaged for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "rclone";
  inherit version;

  src = fetchurl {
    url = "https://github.com/tgdrive/rclone/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  sourceRoot = source.dir;

  nativeBuildInputs = [
    unzip
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 rclone "$out/bin/rclone"
    install -Dm644 rclone.1 "$out/share/man/man1/rclone.1"

    runHook postInstall
  '';

  meta = {
    description = "Rclone fork from tgdrive";
    homepage = "https://github.com/tgdrive/rclone";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "rclone";
    platforms = builtins.attrNames sources;
  };
}
