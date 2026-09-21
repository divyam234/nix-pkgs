{ originalDbeaverBin, fetchurl, stdenv }:

let
  version = "26.2.1";

  sources = {
    x86_64-linux = {
      asset = "dbeaver-ce-26.2.1-linux-x86_64.tar.gz";
      hash = "sha256-Fte9AehPjNj0bWl2rBJ/olZ47AEJU8m03OQZM68gZ+g=";
    };

    aarch64-linux = {
      asset = "dbeaver-ce-26.2.1-linux-aarch64.tar.gz";
      hash = "sha256-dvrR2QZNDtra33rIEbM7Z17KeXoQjcRqjjgtoiOZzI4=";
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
