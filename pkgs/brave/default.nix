{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.94.119";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.94.119_amd64.deb";
      hash = "sha256-yZEds+pDOx8ZGvz0AmRj3Js8pUm/obsGKO7D1Ld30lc=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.94.119_arm64.deb";
      hash = "sha256-CoZi4Xf+BMAsmlR3To49RAaq5XmWen05/volVLm3dqA=";
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
