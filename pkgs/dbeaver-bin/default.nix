{ originalDbeaverBin, fetchurl, stdenv }:

let
  version = "26.1.3";

  sources = {
    x86_64-linux = {
      asset = "dbeaver-ce-26.1.3-linux-x86_64.tar.gz";
      hash = "sha256-cPRmReV6F+pCkrbF7d1m+bQjOaJCCFndNSThMWPGrsY=";
    };

    aarch64-linux = {
      asset = "dbeaver-ce-26.1.3-linux-aarch64.tar.gz";
      hash = "sha256-bT1bCKzeiAMJbPa6I6fqQq7OrbkKhgDYAUEKuURHP5g=";
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
