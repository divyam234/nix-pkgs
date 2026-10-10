{
  githubReleaseBinary,
}:

let
  version = "1.5.4";

  sources = {
    x86_64-linux = {
      asset = "spoofdpi_1.5.4_linux_x86_64.tar.gz";
      hash = "sha256-a56BtbEyoQfIgZMa+oJ8Far4NFlFAqfwdg6fhwFn7MY=";
    };

    aarch64-linux = {
      asset = "spoofdpi_1.5.4_linux_arm64.tar.gz";
      hash = "sha256-npv+ZDUFfhtqnBvNwi2dsgLR3yOI6pnabLlzcU/7r3E=";
    };
  };
in
githubReleaseBinary {
  inherit version sources;
  pname = "spoofdpi";
  owner = "xvzc";
  repo = "SpoofDPI";

  binaryName = "spoofdpi";

  meta = {
    description = "Simple and fast anti-censorship tool to bypass DPI";
    homepage = "https://github.com/xvzc/SpoofDPI";
    maintainers = [ ];
  };
}
