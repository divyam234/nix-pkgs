{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.99.55";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.99.55_amd64.deb";
      hash = "sha256-Nk6VSirYTVuj4OIXoinVhzxK5xB9FeYSDkIHUpU5yI0=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.99.55_arm64.deb";
      hash = "sha256-r5nwaDDQllA/Zmezb/btbEVf7vUgPw0o/vTP065e4Qo=";
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
