{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.97.57";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.97.57_amd64.deb";
      hash = "sha256-15kZqCqoac9RIbZBr6eZWHMMS9rzagxRrg+cMvnBa7k=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.97.57_arm64.deb";
      hash = "sha256-vK6U520FsDs8lmQSLyy8OYJ5nv3mBFx3QG4nTXd/eu0=";
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
