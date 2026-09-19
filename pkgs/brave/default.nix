{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.95.104";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.95.104_amd64.deb";
      hash = "sha256-4J48Pp/IT3XmUEigvoMMfEkHdEpAK1eQUw0iBrJ2Qm4=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.95.104_arm64.deb";
      hash = "sha256-JR7oP6OD22EGrmFA3wl1aJsibRXOuWzbQUfLkM18Jbo=";
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
