{ originalBeekeeperStudio, fetchurl, lib, stdenv, unixodbc }:

let
  version = "5.8.1";

  sources = {
    x86_64-linux = {
      asset = "beekeeper-studio_5.8.1_amd64.deb";
      hash = "sha256-e5y7uBzdbDSUQKpxRjho+2kU3wx23spdSv1PwmJ30gA=";
    };

    aarch64-linux = {
      asset = "beekeeper-studio_5.8.1_arm64.deb";
      hash = "sha256-iuZDeSYljiSRUqtLIA1BcrRaYoqg9dnlbRDLsetVkMQ=";
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
