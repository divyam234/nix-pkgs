{
  originalBrave,
  fetchurl,
  stdenv,
  ...
}:

let
  version = "1.98.62";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.98.62_amd64.deb";
      hash = "sha256-+ytsdncm2ytWLXZhmGGLwppZDpj4KZat4qOikVO1VcE=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.98.62_arm64.deb";
      hash = "sha256-lXjpjKXD9QEuvAYNhp8OYmT/PW2WpfBO5zfre/ygdiQ=";
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
