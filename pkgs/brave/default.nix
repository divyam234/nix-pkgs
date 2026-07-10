{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}@args:

let
  version = "1.92.139";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.92.139_amd64.deb";
      hash = "sha256-UFQV8iBsa6HdUhGGngpi341o41yRoenkxbG2M90O62A=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.92.139_arm64.deb";
      hash = "sha256-CkCpXgP4InjfjuhKqG66OjuZcqq7VLLK3/n+7fXpMj0=";
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
