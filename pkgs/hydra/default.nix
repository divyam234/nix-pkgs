{
  githubReleaseBinary,
}:

let
  version = "1.0.3";

  sources = {
    x86_64-linux = {
      asset = "hydra_Linux_x86_64.tar.gz";
      hash = "sha256-Oi4pVy0hqlLSA1XuzV1tzOSF+NRNf9aEOmTeGmo+Uk0=";
    };

    aarch64-linux = {
      asset = "hydra_Linux_arm64.tar.gz";
      hash = "sha256-MFbMIsb5XR95Mmmq4ACqqR/h7a6Tmhw7Pp41DNt/3SY=";
    };
  };
in
githubReleaseBinary {
  inherit version sources;
  pname = "hydra";
  owner = "divyam234";
  repo = "hydra";

  binaryName = "hydra";

  meta = {
    description = "Go-native HTTP/HTTPS download manager";
    homepage = "https://github.com/divyam234/hydra";
    maintainers = [ ];
  };
}
