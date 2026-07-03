{
  githubReleaseBinary,
}:

let
  version = "0.6.4";

  sources = {
    x86_64-linux = {
      asset = "codeforge_0.6.4_linux_amd64.tar.gz";
      hash = "sha256-22PEzjW7PclAlR/revqNPpLcBSNQmZ4ctXvv0Yu+Xek=";
    };

    aarch64-linux = {
      asset = "codeforge_0.6.4_linux_arm64.tar.gz";
      hash = "sha256-ps5YjR9r6RWM1eJ4R+hmb9pqXH8K8PEZOWzGvBJVK28=";
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
