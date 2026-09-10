{
  githubReleaseBinary,
}:

let
  version = "0.6.7";

  sources = {
    x86_64-linux = {
      asset = "codeforge_0.6.7_linux_amd64.tar.gz";
      hash = "sha256-cjz57rZ58UtQPbCaKuWJMk55ueXsbljxrwA4gnI4di0=";
    };

    aarch64-linux = {
      asset = "codeforge_0.6.7_linux_arm64.tar.gz";
      hash = "sha256-KKNs9hkRzDu4ieheq/t3NyFNsCW5YXQbkJkJe0Dxpk4=";
    };
  };
in
githubReleaseBinary {
  inherit version sources;
  pname = "codeforge";
  owner = "divyam234";
  repo = "codeforge";

  binaryName = "codeforge";

  meta = {
    description = "Model-neutral coding workspace runtime with MCP, OpenAPI, Git, file, plan, and process tools";
    homepage = "https://github.com/divyam234/codeforge";
    maintainers = [ ];
  };
}
