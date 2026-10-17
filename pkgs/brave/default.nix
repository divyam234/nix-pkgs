{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.97.59";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.97.59_amd64.deb";
      hash = "sha256-Zm+Be2QKMoT7tcmzSRe3iFTirNkvp/661wTcKyk0m+U=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.97.59_arm64.deb";
      hash = "sha256-Xv3SNWZx6t4x09ClmyM4kxFH9l8NtEhjtsI63qdLodI=";
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
