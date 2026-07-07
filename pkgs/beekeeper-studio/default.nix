{ originalBeekeeperStudio, fetchurl, lib, stdenv, unixodbc }:

let
  version = "5.9.1";

  sources = {
    x86_64-linux = {
      asset = "beekeeper-studio_5.9.1_amd64.deb";
      hash = "sha256-pgf++yAfBw6xtX4UM8aZujDI1oylVpK4U7KWM+mWwJ4=";
    };

    aarch64-linux = {
      asset = "beekeeper-studio_5.9.1_arm64.deb";
      hash = "sha256-rYVIMrZiAPnjuuSM6FocfqDUD7Y3/zABkLW16zrqj1s=";
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
