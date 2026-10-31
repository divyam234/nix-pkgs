{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.98.63";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.98.63_amd64.deb";
      hash = "sha256-JCJ81aklnr3FEI2zlMxZmN9aw2NfhPiDinRkp7XN3VU=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.98.63_arm64.deb";
      hash = "sha256-jQtKAVXCgQ7JwuK3VRWbmieL1R+50Nd2ynrE9C4MwvM=";
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
