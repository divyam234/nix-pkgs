{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}@args:

let
  version = "1.92.140";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.92.140_amd64.deb";
      hash = "sha256-IB2jRvtO30OAqyEZRgeuyNU9eLgIXJj7rLOooZcDuKY=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.92.140_arm64.deb";
      hash = "sha256-erH7ydVvVykPKYyrIRsn/FCh/ZCU0G+WrubOtfAxFYA=";
    };
  };

  sys = stdenv.hostPlatform.system;
  braveArgs = builtins.removeAttrs args [
    "originalBrave"
    "fetchurl"
    "stdenv"
  ];
in
(originalBrave.override braveArgs).overrideAttrs (old: {
  inherit version;

  src = fetchurl {
    url = "https://github.com/brave/brave-browser/releases/download/v${version}/${sources.${sys}.asset}";
    hash = sources.${sys}.hash;
  };
})
