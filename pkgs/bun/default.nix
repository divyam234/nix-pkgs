{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  openssl,
  unzip,
}:

let
  version = "1.3.14";

  sources = {
    x86_64-linux = {
      asset = "bun-linux-x64.zip";
      hash = "sha256-lR7iruhV8IWVruxiJSJqKY0/6oOj3NZGXAnLzN9+hI8=";
      dir = "bun-linux-x64";
    };

    aarch64-linux = {
      asset = "bun-linux-aarch64.zip";
      hash = "sha256-on/7Y6gxA3WDbg1vZorhf6jY0YuIw3yCHGUzGXOhmjs=";
      dir = "bun-linux-aarch64";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system} or (throw "bun is not packaged for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "bun";
  inherit version;

  src = fetchurl {
    url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/${source.asset}";
    inherit (source) hash;
  };

  sourceRoot = source.dir;

  nativeBuildInputs = [
    autoPatchelfHook
    unzip
  ];

  buildInputs = [
    openssl
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bun "$out/bin/bun"
    ln -s "$out/bin/bun" "$out/bin/bunx"

    runHook postInstall
  '';

  meta = {
    description = "Incredibly fast JavaScript runtime, bundler, transpiler and package manager";
    homepage = "https://bun.sh";
    license = with lib.licenses; [
      mit
      lgpl21Only
    ];
    maintainers = [ ];
    mainProgram = "bun";
    platforms = builtins.attrNames sources;
  };
}
