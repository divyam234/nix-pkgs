{ originalBeekeeperStudio, fetchurl, lib, stdenv, unixodbc }:

let
  version = "6.1.2";

  sources = {
    x86_64-linux = {
      asset = "beekeeper-studio_6.1.2_amd64.deb";
      hash = "sha256-yWTb33Lv2GS8/bF3y0ryo/Tjy5cxegK1e8AqfU5F6jM=";
    };

    aarch64-linux = {
      asset = "beekeeper-studio_6.1.2_arm64.deb";
      hash = "sha256-RoYzPivsG1jARhmp7dBxZHQksFEl57TQFyy7dDQsYlk=";
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
