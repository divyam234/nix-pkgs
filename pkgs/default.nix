{ pkgs, prev }:

let
  githubReleaseBinary = pkgs.callPackage ../lib/github-release-binary.nix { };
in
{
  aria2 = pkgs.callPackage ./aria2 {
    inherit githubReleaseBinary;
  };

  bun = pkgs.callPackage ./bun { };

  rclone = pkgs.callPackage ./rclone { };

  teldrive = pkgs.callPackage ./teldrive {
    inherit githubReleaseBinary;
  };

  opencode = pkgs.callPackage ./opencode {
    inherit githubReleaseBinary;
  };

  mcontrolcenter = pkgs.callPackage ./mcontrolcenter { };

  nordvpn = pkgs.callPackage ./nordvpn { };

  brave = pkgs.callPackage ./brave { originalBrave = prev.brave; };

  dbeaver-bin = pkgs.callPackage ./dbeaver-bin { originalDbeaverBin = prev.dbeaver-bin; };

  zed-editor = pkgs.callPackage ./zed-editor { };

  zjstatus = pkgs.callPackage ./zjstatus { };
}
