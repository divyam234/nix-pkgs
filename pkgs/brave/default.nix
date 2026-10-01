{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.96.60";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.96.60_amd64.deb";
      hash = "sha256-EAFHm5kfs/0nm4ZouWL7qjfpxVy6MbMRawa9ZZBaios=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.96.60_arm64.deb";
      hash = "sha256-davGR6BaIQqgNesh6azWG9OsyvO2zD59fE0TxoHU7xM=";
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
