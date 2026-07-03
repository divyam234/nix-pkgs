{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}@args:

let
  version = "1.92.134";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.92.134_amd64.deb";
      hash = "sha256-T3A/ejmLkIRYGWc8GXQmvIAZvQFwYEyhQJxssNDalhQ=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.92.134_arm64.deb";
      hash = "sha256-qo40t+PGl1RO2ajJ2Hev4G1FWvzTx7Ak5CVxjdxabLI=";
    };
  };

  sys = stdenv.hostPlatform.system;
  braveArgs = builtins.removeAttrs args [
    "originalBrave"
    "fetchurl"
    "stdenv"
  ];
in
(originalBrave.override braveArgs).overrideAttrs (old: {
  inherit version;

  src = fetchurl {
    url = "https://github.com/brave/brave-browser/releases/download/v${version}/${sources.${sys}.asset}";
    hash = sources.${sys}.hash;
  };
})
