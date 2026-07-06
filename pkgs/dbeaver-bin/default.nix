{ originalDbeaverBin, fetchurl, stdenv }:

let
  version = "26.1.2";

  sources = {
    x86_64-linux = {
      asset = "dbeaver-ce-26.1.2-linux-x86_64.tar.gz";
      hash = "sha256-j4Zu8iOj5WQ7eFGVFTA6Ssxi+x7oSLMaEHOfLmktWb0=";
    };

    aarch64-linux = {
      asset = "dbeaver-ce-26.1.2-linux-aarch64.tar.gz";
      hash = "sha256-9dYgA4V+6Wqifu/dJYyK4cxOrP+vc4SezrrdDUFTKnw=";
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
