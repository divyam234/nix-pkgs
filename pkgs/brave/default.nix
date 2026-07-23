{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}@args:

let
  version = "1.92.143";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.92.143_amd64.deb";
      hash = "sha256-jaxNneurduBiw3jho5Fp7gXnBfSpLB5hlE06i/JK+ic=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.92.143_arm64.deb";
      hash = "sha256-IHBJm9uow2d/X4Z9e117aGdP1Y+3R1ApWu40sPtdbr8=";
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
