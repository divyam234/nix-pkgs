{
  githubReleaseBinary,
}:

let
  version = "0.6.6";

  sources = {
    x86_64-linux = {
      asset = "codeforge_0.6.6_linux_amd64.tar.gz";
      hash = "sha256-wL72SS1YbuQPMZKif5IkSv6xrIAkQJqm1lrlx+e0FSY=";
    };

    aarch64-linux = {
      asset = "codeforge_0.6.6_linux_arm64.tar.gz";
      hash = "sha256-BLy990UE0DT+rmKuCeG3HJb52ZZu41Qt4cAs2IOG9ic=";
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
