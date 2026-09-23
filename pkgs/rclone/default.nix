{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "1.75.2";

  sources = {
    x86_64-linux = {
      asset = "rclone-v1.75.2-linux-amd64.tar.gz";
      hash = "sha256-eq+goCmL6JwDwUkdDlO95McvpMZ98tmyhV7LhoS9x+c=";
      dir = "rclone-v${version}-linux-amd64";
    };

    aarch64-linux = {
      asset = "rclone-v1.75.2-linux-arm64.tar.gz";
      hash = "sha256-KYiFQJm25LGSnfM55ectv3zyJAvFnJMftoFs4EFf4ek=";
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
