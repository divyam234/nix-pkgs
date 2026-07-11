{ originalBeekeeperStudio, fetchurl, lib, stdenv, unixodbc }:

let
  version = "5.9.2";

  sources = {
    x86_64-linux = {
      asset = "beekeeper-studio_5.9.2_amd64.deb";
      hash = "sha256-O987wpgrue1yD4jgm0x0IpfbaTKNZrjhabTiwv94caA=";
    };

    aarch64-linux = {
      asset = "beekeeper-studio_5.9.2_arm64.deb";
      hash = "sha256-IZc9VVo66CQjqQUKz4DNvWWAa2JArwqiVTgdLbR9uDk=";
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
