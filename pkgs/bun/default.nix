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
  version = "1.4.5";

  sources = {
    x86_64-linux = {
      asset = "bun-linux-x64.zip";
      hash = "sha256-lFWbO1KJlaSUUvnyQEzsdPLv19BuCgAKjNIUsCw2Zus=";
      dir = "bun-linux-x64";
    };

    x86_64-linux-baseline = {
      asset = "bun-linux-x64-baseline.zip";
      hash = "sha256-3LI6GKHC//EtV7zvaW27tC62f94p9DgW7LWVRZokxGM=";
      dir = "bun-linux-x64-baseline";
    };

    aarch64-linux = {
      asset = "bun-linux-aarch64.zip";
      hash = "sha256-GGVqO/DqVkH1eWrkITt1JVV5pwoP3tLzN5M3hVaM34Q=";
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
