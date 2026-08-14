{ originalBeekeeperStudio, fetchurl, lib, stdenv, unixodbc }:

let
  version = "6.0.1";

  sources = {
    x86_64-linux = {
      asset = "beekeeper-studio_6.0.1_amd64.deb";
      hash = "sha256-CaTPN0OyCHY2xj0jml9O0UdDShUtmJMsVSZzSQFoFII=";
    };

    aarch64-linux = {
      asset = "beekeeper-studio_6.0.1_arm64.deb";
      hash = "sha256-GnP/fBBwjAyzOQEni10wNXmSz1SZ4trCR2MtQ0kpnHI=";
    };
  };

  sys = stdenv.hostPlatform.system;
in
originalBeekeeperStudio.overrideAttrs (old: {
  inherit version;

  buildInputs = (old.buildInputs or [ ]) ++ [ unixodbc ];

  postFixup = (old.postFixup or "") + ''
    wrapProgram $out/bin/beekeeper-studio \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ unixodbc ]}
  '';

  src = fetchurl {
    url = "https://github.com/beekeeper-studio/beekeeper-studio/releases/download/v${version}/${sources.${sys}.asset}";
    hash = sources.${sys}.hash;
  };
})
