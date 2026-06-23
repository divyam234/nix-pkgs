{ originalDbeaverBin, fetchurl, stdenv }:

let
  version = "26.1.1";

  sources = {
    x86_64-linux = {
      asset = "dbeaver-ce-${version}-linux-x86_64.tar.gz";
      hash = "sha256-atbQ00lq589FlNem85NgzTKGyhTRpFII8OSfVfYQuD0=";
    };

    aarch64-linux = {
      asset = "dbeaver-ce-${version}-linux-aarch64.tar.gz";
      hash = "sha256-Sde0q31hXMqX2oxfhgj5EcpeUYYFZJy61usaJVpZkLM=";
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
