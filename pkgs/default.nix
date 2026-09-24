{ pkgs, prev }:

let
  githubReleaseBinary = pkgs.callPackage ../lib/github-release-binary.nix { };
in
{
  aria2 = pkgs.callPackage ./aria2 { };

  bun = pkgs.callPackage ./bun { };

  codeforge = pkgs.callPackage ./codeforge {
    inherit githubReleaseBinary;
  };


  gost = pkgs.callPackage ./gost { };

  hydra = pkgs.callPackage ./hydra {
    inherit githubReleaseBinary;
  };

  rclone = pkgs.callPackage ./rclone { };

  restic = pkgs.callPackage ./restic { };

  sublime = pkgs.callPackage ./sublime { };

  teldrive = pkgs.callPackage ./teldrive {
    inherit githubReleaseBinary;
  };

  opencode = pkgs.callPackage ./opencode { };

  mcontrolcenter = pkgs.callPackage ./mcontrolcenter { };

  nordvpn = pkgs.callPackage ./nordvpn { };

  brave = pkgs.callPackage ./brave { originalBrave = prev.brave; };

  foliate = pkgs.callPackage ./foliate { };

  zed-editor = pkgs.callPackage ./zed-editor { };

  zjstatus = pkgs.callPackage ./zjstatus { };

  ida-pro = pkgs.callPackage ./ida-pro { };

  tailscale = pkgs.callPackage ./tailscale { };
}
