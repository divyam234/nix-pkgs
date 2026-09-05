{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.94.121";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.94.121_amd64.deb";
      hash = "sha256-IdesNrZKQI3FmLtuw9uEsHssvKhU0msoBVovtblKLnc=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.94.121_arm64.deb";
      hash = "sha256-7Cp4SGDpEszD32iHovx6VEJzIc2qhPHmF0UL1x7g7Hs=";
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
