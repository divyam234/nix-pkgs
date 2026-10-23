{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.98.60";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.98.60_amd64.deb";
      hash = "sha256-gSoAHXYxtatJ5V3sYUigvC1Fnp/AMQbChile4D/QYvw=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.98.60_arm64.deb";
      hash = "sha256-mqbdSwo0a/5+6WdBllhvfy1I2MonRcttDNj7GStLsEc=";
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
