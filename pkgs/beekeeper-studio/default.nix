{ originalBeekeeperStudio, fetchurl, lib, stdenv, unixodbc }:

let
  version = "6.1.1";

  sources = {
    x86_64-linux = {
      asset = "beekeeper-studio_6.1.1_amd64.deb";
      hash = "sha256-sYfAxxBHDV+D+9EcbHP24/n1Ua97e3eScqz/+DMuceg=";
    };

    aarch64-linux = {
      asset = "beekeeper-studio_6.1.1_arm64.deb";
      hash = "sha256-EGPJPQ+CUVni2wXtLJUkmNthOQnC+rQW5A4LyNPgmqY=";
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
