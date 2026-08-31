{ originalDbeaverBin, fetchurl, stdenv }:

let
  version = "26.2.0";

  sources = {
    x86_64-linux = {
      asset = "dbeaver-ce-26.2.0-linux-x86_64.tar.gz";
      hash = "sha256-9QTnCnR2OqAuC2PWhCuFymRSb2gr5Fez8w4zDMEHSO0=";
    };

    aarch64-linux = {
      asset = "dbeaver-ce-26.2.0-linux-aarch64.tar.gz";
      hash = "sha256-atqAOjnAcvyPHHdwZpKY6So1AXRKbh/5GXlKDe35WWM=";
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
