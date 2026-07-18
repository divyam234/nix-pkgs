{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}@args:

let
  version = "1.92.141";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.92.141_amd64.deb";
      hash = "sha256-A87vCTtcyuNMPLaLYDjgyIm85zwAXNc3Z4ImtC9Kjek=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.92.141_arm64.deb";
      hash = "sha256-FVzXaVpyfX+GIVofy3NfpE8rOH+9LjQpdEoEWQV0DqI=";
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
