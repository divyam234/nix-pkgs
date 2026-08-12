{ originalBeekeeperStudio, fetchurl, lib, stdenv, unixodbc }:

let
  version = "6.0.0";

  sources = {
    x86_64-linux = {
      asset = "beekeeper-studio_6.0.0_amd64.deb";
      hash = "sha256-mTS5elz54AbbYF6AtPaeZvbR7ysB6a6iu+lbaTrwv5k=";
    };

    aarch64-linux = {
      asset = "beekeeper-studio_6.0.0_arm64.deb";
      hash = "sha256-KSz60oSR5UcVM5p8swRqBCZknGob7/MEMtAI2UmN2Q0=";
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
