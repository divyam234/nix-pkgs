{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  openssl,
  runtimeShell,
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

    x86_64-linux-baseline = {
      asset = "bun-linux-x64-baseline.zip";
      hash = "sha256-oGOQiuCLeFLKEJObvcbO7T3avOj7lALc6D1l1zs25sc=";
      dir = "bun-linux-x64-baseline";
    };

    aarch64-linux = {
      asset = "bun-linux-aarch64.zip";
      hash = "sha256-on/7Y6gxA3WDbg1vZorhf6jY0YuIw3yCHGUzGXOhmjs=";
      dir = "bun-linux-aarch64";
    };
  };

  system = stdenvNoCC.hostPlatform.system;
  source = sources.${system} or (throw "bun is not packaged for ${system}");
  isX86_64 = stdenvNoCC.hostPlatform.isx86_64;
  baselineSource = sources.x86_64-linux-baseline;
  baselineSrc = fetchurl {
    url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/${baselineSource.asset}";
    inherit (baselineSource) hash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "bun";
  inherit version;
  inherit baselineSrc;

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

  installPhase =
    if isX86_64 then
      ''
        runHook preInstall

        install -Dm755 bun "$out/libexec/bun"
        mkdir baseline
        unzip -q "$baselineSrc" -d baseline
        install -Dm755 "baseline/${baselineSource.dir}/bun" "$out/libexec/bun-baseline"
        install -Dm755 /dev/stdin "$out/bin/bun" <<EOF
        #!${runtimeShell}

        if [[ -r /proc/cpuinfo && \$(< /proc/cpuinfo) == *avx2* ]]; then
          exec "$out/libexec/bun" "\$@"
        fi

        exec "$out/libexec/bun-baseline" "\$@"
        EOF
        ln -s "$out/bin/bun" "$out/bin/bunx"

        runHook postInstall
      ''
    else
      ''
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
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
