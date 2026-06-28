{
  githubReleaseBinary,
}:

let
  version = "1.0.2";

  sources = {
    x86_64-linux = {
      asset = "hydra_Linux_x86_64.tar.gz";
      hash = "sha256-zZ4LM9m+Ta9GayOCqn4aznNzSD+t9cLvfYGE2xw62L0=";
    };

    aarch64-linux = {
      asset = "hydra_Linux_arm64.tar.gz";
      hash = "sha256-Fcb49TMWw3ek6vkzIFaLl/w9GG63tzXtjLSfBKaJCN4=";
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
