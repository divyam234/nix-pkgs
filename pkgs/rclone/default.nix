{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "1.75.1";

  sources = {
    x86_64-linux = {
      asset = "rclone-v1.75.1-linux-amd64.tar.gz";
      hash = "sha256-/62UsDAS6AWt87wGmBlzBnoR/+4U8UnVz0Z16SoeNiQ=";
      dir = "rclone-v${version}-linux-amd64";
    };

    aarch64-linux = {
      asset = "rclone-v1.75.1-linux-arm64.tar.gz";
      hash = "sha256-29JwivNm4LDZc6F/Yx0c+FEppr2hdhaB+fawofTljs0=";
      dir = "rclone-v${version}-linux-arm64";
    };
  };

  source = sources.${stdenv.hostPlatform.system} or (throw "rclone is not packaged for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "rclone";
  inherit version;

  src = fetchurl {
    url = "https://github.com/divyam234/nix-pkgs/releases/download/rclone-v${version}/${source.asset}";
    inherit (source) hash;
  };

  sourceRoot = source.dir;

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
