{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.96.59";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.96.59_amd64.deb";
      hash = "sha256-sFEpxpB2cLICni8Bdz0ZLIuHwwdbJYc+o7wia7DxXx4=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.96.59_arm64.deb";
      hash = "sha256-uCp6SIybwMexj+oaLaistJ9CtKhWST1qTOdaC5pJ/uM=";
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
