{
  lib,
  githubReleaseBinary,
}:

let
  version = "1.37.0";

  sources = {
    x86_64-linux = {
      asset = "aria2-static-linux-x86_64.tar.gz";
      hash = "sha256-2Ju1RCF1jrFRtL3Fhfh5Wb3El9dKRtFZGVT/fzUvrmY=";
    };

    aarch64-linux = {
      asset = "aria2-static-linux-arm64.tar.gz";
      hash = "sha256-Sy3a7JlVDgXq7hwAWFVetsjZvcTEnUdGvUt8L8XHLUA=";
    };
  };
in
githubReleaseBinary {
  inherit version sources;
  pname = "aria2";
  owner = "divyam234";
  repo = "nix-pkgs";
  downloadTag = "aria2-v${version}";
  binaryName = "aria2c";

  meta = {
    description = "Patched static aria2c binary";
    homepage = "https://github.com/aria2/aria2";
    license = lib.licenses.gpl2Plus;
    maintainers = [ ];
  };
}
