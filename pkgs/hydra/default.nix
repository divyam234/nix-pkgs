{
  githubReleaseBinary,
}:

let
  version = "1.0.5";

  sources = {
    x86_64-linux = {
      asset = "hydra_Linux_x86_64.tar.gz";
      hash = "sha256-fXf0HyAbu3mP5WRKTgaJDtbbkt1++zw0zLFOv1Y9WEU=";
    };

    aarch64-linux = {
      asset = "hydra_Linux_arm64.tar.gz";
      hash = "sha256-eovd11iFEUBoZGZ6fIx0QgPy3SZ7ZM+ZWxshSQJy3WY=";
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
