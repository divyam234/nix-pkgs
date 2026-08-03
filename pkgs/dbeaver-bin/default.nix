{ originalDbeaverBin, fetchurl, stdenv }:

let
  version = "26.1.4";

  sources = {
    x86_64-linux = {
      asset = "dbeaver-ce-26.1.4-linux-x86_64.tar.gz";
      hash = "sha256-vySdu/BStELNyi5kO6cixwnlM7fgpQdfumoh18UBMeI=";
    };

    aarch64-linux = {
      asset = "dbeaver-ce-26.1.4-linux-aarch64.tar.gz";
      hash = "sha256-WulNI5kAvrBBFue17uxHPpOQW+dmYrq6l4XnQaukZ2M=";
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
