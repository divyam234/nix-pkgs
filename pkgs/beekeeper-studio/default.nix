{ originalBeekeeperStudio, fetchurl, lib, stdenv, unixodbc }:

let
  version = "6.1.0";

  sources = {
    x86_64-linux = {
      asset = "beekeeper-studio_6.1.0_amd64.deb";
      hash = "sha256-7TV58YyV7DU54x1mFhhsNWdjK/Tnmf6w4BxHlWO3Mhw=";
    };

    aarch64-linux = {
      asset = "beekeeper-studio_6.1.0_arm64.deb";
      hash = "sha256-IV3aGrhR6WU8E+PCqmcRkH/YF5PW5c5SFMDSy4K529w=";
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
