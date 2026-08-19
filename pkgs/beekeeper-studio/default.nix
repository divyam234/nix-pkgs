{ originalBeekeeperStudio, fetchurl, lib, stdenv, unixodbc }:

let
  version = "6.0.4";

  sources = {
    x86_64-linux = {
      asset = "beekeeper-studio_6.0.4_amd64.deb";
      hash = "sha256-smRbK5CxvpB/8kq3WqjBnpI229ygHUTElOadDi8Njsk=";
    };

    aarch64-linux = {
      asset = "beekeeper-studio_6.0.4_arm64.deb";
      hash = "sha256-bL/oCoyIVbC0J1wXcHo5a/flzOGuNIZkIJPOHbv9EKQ=";
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
