{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.93.129";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.93.129_amd64.deb";
      hash = "sha256-fOyneo8kzoGqldT6nYRzFqgy1+WhKGhcSkJQTCd4w6k=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.93.129_arm64.deb";
      hash = "sha256-pO6vTzTv7OKcP5uJwlcc+vUdg/0Lm2Q6apnEhjRxasM=";
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
