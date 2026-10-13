{ pkgs, prev }:

let
  githubReleaseBinary = pkgs.callPackage ../lib/github-release-binary.nix { };
  gpuiApp = pkgs.callPackage ../lib/gpui-app.nix { };
in
{
  aria2 = pkgs.callPackage ./aria2 { };

  bun = pkgs.callPackage ./bun { };

  codeforge = pkgs.callPackage ./codeforge {
    inherit githubReleaseBinary;
  };

  disktree = pkgs.callPackage ./disktree {
    inherit gpuiApp;
  };


  gost = pkgs.callPackage ./gost { };

  hydra = pkgs.callPackage ./hydra {
    inherit githubReleaseBinary;
  };

  rclone = pkgs.callPackage ./rclone { };

  restic = pkgs.callPackage ./restic { };

  sublime = pkgs.callPackage ./sublime { };

  opencode = pkgs.callPackage ./opencode { };

  pdfcraft = pkgs.callPackage ./pdfcraft { };

  probe = pkgs.callPackage ./probe {
    inherit gpuiApp;
  };

  mcontrolcenter = pkgs.callPackage ./mcontrolcenter { };

  nordvpn = pkgs.callPackage ./nordvpn { };

  brave = pkgs.callPackage ./brave { originalBrave = prev.brave; };

  foliate = pkgs.callPackage ./foliate { };

  fluxdown = pkgs.callPackage ./fluxdown {
    inherit gpuiApp;
  };

  tusk = pkgs.callPackage ./tusk {
    inherit gpuiApp;
  };

  zed-editor = pkgs.callPackage ./zed-editor {
    inherit gpuiApp;
  };

  zjstatus = pkgs.callPackage ./zjstatus { };

  ida-pro = pkgs.callPackage ./ida-pro { };
}
