{ originalBeekeeperStudio, fetchurl, lib, stdenv, unixodbc }:

let
  version = "5.9.3";

  sources = {
    x86_64-linux = {
      asset = "beekeeper-studio_5.9.3_amd64.deb";
      hash = "sha256-ngVE7hjtr/a6CBASwZA3gmvk7+WR2okQy+ywXbEUQpk=";
    };

    aarch64-linux = {
      asset = "beekeeper-studio_5.9.3_arm64.deb";
      hash = "sha256-aAoputvhCHqekT+pdaZEmps4aa48gz9DDCgomJvWQSw=";
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
