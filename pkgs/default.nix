{ pkgs, prev }:

let
  githubReleaseBinary = pkgs.callPackage ../lib/github-release-binary.nix { };
in
{
  bun = pkgs.callPackage ./bun { };

  codeforge = pkgs.callPackage ./codeforge {
    inherit githubReleaseBinary;
  };

  hydra = pkgs.callPackage ./hydra {
    inherit githubReleaseBinary;
  };

  rclone = pkgs.callPackage ./rclone { };

  restic = pkgs.callPackage ./restic { };

  sublime = pkgs.callPackage ./sublime { };

  teldrive = pkgs.callPackage ./teldrive {
    inherit githubReleaseBinary;
  };

  opencode = pkgs.callPackage ./opencode {
    inherit githubReleaseBinary;
  };

  mcontrolcenter = pkgs.callPackage ./mcontrolcenter { };

  nordvpn = pkgs.callPackage ./nordvpn { };

  brave = pkgs.callPackage ./brave { originalBrave = prev.brave; };

  beekeeper-studio = pkgs.callPackage ./beekeeper-studio {
    originalBeekeeperStudio = prev.beekeeper-studio;
  };

  dbeaver-bin = pkgs.callPackage ./dbeaver-bin { originalDbeaverBin = prev.dbeaver-bin; };

  foliate = pkgs.callPackage ./foliate { };

  zed-editor = pkgs.callPackage ./zed-editor { };

  zjstatus = pkgs.callPackage ./zjstatus { };

  ida-pro = pkgs.callPackage ./ida-pro { };
}
// prev.lib.optionalAttrs prev.stdenv.hostPlatform.isx86_64 {
  noctalia = pkgs.callPackage ./noctalia { };
  noctalia-greeter = pkgs.callPackage ./noctalia-greeter { };
}
