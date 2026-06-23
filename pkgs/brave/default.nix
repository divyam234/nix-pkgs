{ originalBrave, fetchurl, stdenv }:

let
  version = "1.91.175";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.91.175_amd64.deb";
      hash = "sha256-/+xaqBCYzo4bvYASoRgDHDIUb2aWX1DGxqfDifeWKSQ=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.91.175_arm64.deb";
      hash = "sha256-7O7cK9Y0nqn60G/4J7Tit0Z1ndsEgs9WtwS1yrDGZ0Y=";
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
