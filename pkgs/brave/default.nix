{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.93.137";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.93.137_amd64.deb";
      hash = "sha256-Z3fYjvds3MTDdH3QZeCztX3GTHn2gg5AeJ3WY7GOunI=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.93.137_arm64.deb";
      hash = "sha256-ef7uKI8RqY8h0fGvrG+6Ys6i3sML2DbdtK4N5/ce2f4=";
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
