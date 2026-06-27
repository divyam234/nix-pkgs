{ originalBrave, fetchurl, stdenv }:

let
  version = "1.91.180";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.91.180_amd64.deb";
      hash = "sha256-mM2SOn6V1KQJEjxR0KH1lXJMLSzpx/IiZDeSrJtIFt0=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.91.180_arm64.deb";
      hash = "sha256-HdmJBLANsmlBi3EtzeuMn4USmW8x/LaYKUWDlqw3a2I=";
    };
  };

  sys = stdenv.hostPlatform.system;
in
originalBrave.overrideAttrs (old: {
  inherit version;

  src = fetchurl {
    url = "https://github.com/brave/brave-browser/releases/download/v${version}/${sources.${sys}.asset}";
    hash = sources.${sys}.hash;
  };
})
