{ originalDbeaverBin, fetchurl, stdenv }:

let
  version = "26.1.5";

  sources = {
    x86_64-linux = {
      asset = "dbeaver-ce-26.1.5-linux-x86_64.tar.gz";
      hash = "sha256-DoqiAIgUxRwdhj+Pq5vOA0P1wd/g7064a7DhO7pMHvI=";
    };

    aarch64-linux = {
      asset = "dbeaver-ce-26.1.5-linux-aarch64.tar.gz";
      hash = "sha256-O87LRTJ8S9FLFEO2n9gNt0vPruY0AEzrffNYm7fx1nQ=";
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
