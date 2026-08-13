{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.93.136";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.93.136_amd64.deb";
      hash = "sha256-lznlqu5DA+tBmcA4sEp117x6wIMUr592MBHiEd6mKZk=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.93.136_arm64.deb";
      hash = "sha256-M02+zpWert27gtP+Cdp1raFFDGj2xi053AveDHfGS+o=";
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
