{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.93.134";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.93.134_amd64.deb";
      hash = "sha256-uhdwTBLFUJ9oCQIQx0eetGoIXCN28UmJzqEjLENhIvo=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.93.134_arm64.deb";
      hash = "sha256-4BynMi0YSpa1leSGX9b4/lLrEcM+Lu+Y78EmacmidSA=";
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
