{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.93.132";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.93.132_amd64.deb";
      hash = "sha256-/OXBlJso9d4Kk/stRzuw3p6Hs7Vy4VgocXQJkGULhqU=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.93.132_arm64.deb";
      hash = "sha256-XPVNloQWcQb/2rdx/SGfVcV6MNAlAutW/VHKXdRWn0o=";
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
