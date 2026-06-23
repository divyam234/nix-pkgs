{ originalDbeaverBin, fetchurl, stdenv }:

let
  version = "26.1.1";

  sources = {
    x86_64-linux = {
      asset = "dbeaver-ce-26.1.1-linux-x86_64.deb";
      hash = "sha256-2Ip65nUSTe4oo72jORfNrNVYRs8FGqYPRqEdmoEIOCc=";
    };

    aarch64-linux = {
      asset = "dbeaver-ce-26.1.1-linux-aarch64.deb";
      hash = "sha256-2me7uL8CbkUUxFmJec3EQzciIpPGEHsZBZ2vPlKZy9A=";
    };
  };

  sys = stdenv.hostPlatform.system;
in
originalDbeaverBin.overrideAttrs (old: {
  inherit version;

  src = fetchurl {
    url = "https://github.com/dbeaver/dbeaver/releases/download/${version}/${sources.${sys}.asset}";
    hash = sources.${sys}.hash;
  };
})
