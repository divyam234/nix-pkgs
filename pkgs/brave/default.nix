{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.96.61";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.96.61_amd64.deb";
      hash = "sha256-UOgyz04xOYl5YwwGQTLDBTI/0FTM2xjNX06RyTlLt8s=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.96.61_arm64.deb";
      hash = "sha256-fQjhzazFdIUt7BqIl71butJUhnIkS7F0boyuBo4H/94=";
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
