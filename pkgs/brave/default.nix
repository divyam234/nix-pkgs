{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.94.117";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.94.117_amd64.deb";
      hash = "sha256-ZAAX6ZNZS0ogFRjDfmyAoWo4NbXckswHY7Amfh3skyQ=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.94.117_arm64.deb";
      hash = "sha256-4LTeb3BOBv+oRzC409UmSnFQDC3XRtKWmkPUcHOTkuM=";
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
