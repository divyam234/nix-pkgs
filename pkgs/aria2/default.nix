{
  lib,
  githubReleaseBinary,
}:

let
  version = "1.37.0";

  sources = {
    x86_64-linux = {
      asset = "aria2-linux-amd64.tar.gz";
      hash = "sha256-zHrc2dDj8Tf5J3mJlEV4kcmuULnE/5gR+PFU2CF//Fc=";
    };

    aarch64-linux = {
      asset = "aria2-linux-arm64.tar.gz";
      hash = "sha256-nZhyGotvnlCbvFC9h4DfjKFpQVjHKtGqeJNglfEGFrE=";
    };
  };
in
githubReleaseBinary {
  inherit version sources;
  pname = "aria2";
  owner = "divyam234";
  repo = "aria2c-static";
  downloadTag = "release-${version}";

  binaryName = "aria2c";

  meta = {
    description = "Static builds of aria2, a lightweight multi-protocol download utility";
    homepage = "https://github.com/divyam234/aria2c-static";
    license = lib.licenses.gpl2Plus;
    maintainers = [ ];
  };
}
