{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.95.102";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.95.102_amd64.deb";
      hash = "sha256-kwEQ/lfIO+Myc4ipQ+nqy87Ag6PhtLwIvsQTeIQYvf4=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.95.102_arm64.deb";
      hash = "sha256-2S4CdU7HJ0MPUw5R2KOlEEHQ3wfWJYkHLBpNBrvwA3s=";
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
