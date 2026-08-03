{
  githubReleaseBinary,
}:

let
  version = "0.6.5";

  sources = {
    x86_64-linux = {
      asset = "codeforge_0.6.5_linux_amd64.tar.gz";
      hash = "sha256-EyC0lBH6aY5HZPnYTcRpwiW8AgMP+Siie/RMownc1ik=";
    };

    aarch64-linux = {
      asset = "codeforge_0.6.5_linux_arm64.tar.gz";
      hash = "sha256-YOYpMTjtZLPfw2ZuXXixyyEd5WfZ7tXZiXygCIfVnFU=";
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
