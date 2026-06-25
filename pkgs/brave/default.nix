{ originalBrave, fetchurl, stdenv }:

let
  version = "1.91.178";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.91.178_amd64.deb";
      hash = "sha256-HxU6U0JOQLocKwr1MX9kkYQprutS4xaMwLD09SKPSKo=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.91.178_arm64.deb";
      hash = "sha256-H7mDZ/RTUgHLKdGXwDU3uqYWI29FcFYXKcq4QFWfi2A=";
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
