{ pkgs }:

let
  githubReleaseBinary = pkgs.callPackage ../lib/github-release-binary.nix { };
in
{
  rclone = pkgs.callPackage ./rclone { };

  teldrive = pkgs.callPackage ./teldrive {
    inherit githubReleaseBinary;
  };

  opencode = pkgs.callPackage ./opencode {
    inherit githubReleaseBinary;
  };
}
