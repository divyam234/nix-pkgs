{
  lib,
  githubReleaseBinary,
}:

let
  version = "1.37.0";

  sources = {
    x86_64-linux = {
      asset = "aria2-linux-amd64.tar.gz";
      hash = "sha256-pGEiLhdm7sVSTaQ0fFjhw4hjKRj3iI3EDeu49z3d0uc=";
    };

    aarch64-linux = {
      asset = "aria2-linux-arm64.tar.gz";
      hash = "sha256-6POOuhOJb5KOFuOYfhFPFq2os9MtINQL/z12sSb9t/A=";
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
