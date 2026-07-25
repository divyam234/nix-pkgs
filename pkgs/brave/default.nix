{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}@args:

let
  version = "1.92.144";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.92.144_amd64.deb";
      hash = "sha256-no/KD+3EB6CqvVWEmDB/8k2rv1wau469FBXMNWN7z6k=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.92.144_arm64.deb";
      hash = "sha256-Z9uUJRaMx+P35oXtvAnjHyOQOXt8mW5oyyEtnD754x8=";
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
