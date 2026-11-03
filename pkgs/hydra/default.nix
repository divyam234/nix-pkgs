{
  githubReleaseBinary,
}:

let
  version = "1.0.4";

  sources = {
    x86_64-linux = {
      asset = "hydra_Linux_x86_64.tar.gz";
      hash = "sha256-s+7sDxNuEITtf4vMwWB0cAg4pJKhuPCjOkvLj6ZUdLk=";
    };

    aarch64-linux = {
      asset = "hydra_Linux_arm64.tar.gz";
      hash = "sha256-Dwj2krXQIXXUWJZqlxlKZtiAcqvKIox0TVYC27RbhK0=";
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
