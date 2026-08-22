{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.93.138";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.93.138_amd64.deb";
      hash = "sha256-zxiy1EPwZyQeE2YkhMS5Uj8T/wibofwnyI9nkRWGrJ8=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.93.138_arm64.deb";
      hash = "sha256-WWXn2Q2axhh9/KU67v6wf4vmRRXuYmJHbNmyOvvvg9c=";
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
