{
  lib,
  stdenvNoCC,
  fetchurl,
  gpuiApp,
  dpkg,
  dbus,
  postgresql,
}:

let
  version = "0.2.1";

  sources = {
    x86_64-linux = {
      asset = "Tusk-0.2.1-ubuntu-amd64.deb";
      hash = "sha256-y2zaoqNl7Vpg48ykZGFEqsFyrfgkLSpn2QqGdy/5whc=";
    };
  };

  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "tusk is not packaged for ${stdenvNoCC.hostPlatform.system}");
in
gpuiApp {
  pname = "tusk";
  inherit version;

  src = fetchurl {
    url = "https://github.com/alpcanaydin/tusk/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  nativeBuildInputs = [ dpkg ];
  buildInputs = [ dbus ];
  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --extract "$src" .
    runHook postUnpack
  '';
  dontConfigure = true;
  dontBuild = true;
  binaryPath = "bin/tusk";
  extraWrapperArgs = [
    "--set-default"
    "TUSK_PGLS"
    "${placeholder "out"}/bin/postgres-language-server"
    "--set-default"
    "TUSK_SQLS"
    "${placeholder "out"}/bin/sqls"
    "--suffix"
    "PATH"
    ":"
    (lib.makeBinPath [ postgresql ])
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share
    cp -r usr/bin/* $out/bin/
    cp -r usr/share/applications usr/share/icons usr/share/doc $out/share/
    substituteInPlace $out/share/applications/tusk.desktop \
      --replace-fail 'Exec=tusk' "Exec=$out/bin/tusk"

    runHook postInstall
  '';

  meta = {
    description = "Native, keyboard-driven database client";
    homepage = "https://github.com/alpcanaydin/tusk";
    license = lib.licenses.mit;
    mainProgram = "tusk";
    platforms = builtins.attrNames sources;
  };
}
