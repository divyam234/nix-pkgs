{ originalZedEditor, fetchurl, stdenv }:

let
  version = "1.7.2";

  sources = {
    x86_64-linux = {
      asset = "zed-linux-x86_64.tar.gz";
      hash = "sha256-udaYeTTCoDgz9fGWUI8Vq4ho1COW3Bp2Bxhq1w1unAI=";
    };

    aarch64-linux = {
      asset = "zed-linux-aarch64.tar.gz";
      hash = "sha256-KFTis3V+1lILS4+U7HlCbI7CHv0kRMi+/zP0CMkKikg=";
    };
  };

  sys = stdenv.hostPlatform.system;
in
originalZedEditor.overrideAttrs (old: {
  inherit version;

  src = fetchurl {
    url = "https://github.com/zed-industries/zed/releases/download/v${version}/${sources.${sys}.asset}";
    hash = sources.${sys}.hash;
  };
})
