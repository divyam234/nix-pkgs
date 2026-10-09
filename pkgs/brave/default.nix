{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.97.56";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.97.56_amd64.deb";
      hash = "sha256-MOTLids4BWfm/NqrcRChfWJQUX4ihgxr2wLq34mTtmk=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.97.56_arm64.deb";
      hash = "sha256-GdeKxSwZVsfSVKTKO7JPkdL0pH5vtrHcxbQ2gYGKXTs=";
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
