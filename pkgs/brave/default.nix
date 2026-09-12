{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.95.101";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.95.101_amd64.deb";
      hash = "sha256-fEGlWCARfZO4IeVeVd77X2yuioYRXIjzoQJs0n8cc8w=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.95.101_arm64.deb";
      hash = "sha256-gmD/h5bMP8h0EyR4bLtn6lYyD0j3ZwAILIbHNN/S3yU=";
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
