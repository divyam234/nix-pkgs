{ originalBeekeeperStudio, fetchurl, lib, stdenv, unixodbc }:

let
  version = "6.0.5";

  sources = {
    x86_64-linux = {
      asset = "beekeeper-studio_6.0.5_amd64.deb";
      hash = "sha256-AlimxfT2aMPXJQKU7NxSmhqhQApIWp1K5qd3wFRvo/w=";
    };

    aarch64-linux = {
      asset = "beekeeper-studio_6.0.5_arm64.deb";
      hash = "sha256-W+Avv/yKefGk64Wvz3rF7ehYkD73EbsMXqeQi/tXjtw=";
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
