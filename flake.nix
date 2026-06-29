{
  description = "Personal Nix package flake for newer GitHub release packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      packageNames = [
        "aria2"
        "beekeeper-studio"
        "brave"
        "bun"
        "hydra"
        "mcontrolcenter"
        "nordvpn"
        "opencode"
        "rclone"
        "sublime"
        "teldrive"
        "zed-editor"
        "zjstatus"
        "openlogi"
      ];
    in
    {
      overlays.default = final: prev: import ./pkgs { pkgs = final; inherit prev; };

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        (nixpkgs.lib.genAttrs packageNames (name: pkgs.${name})) // {
          all = pkgs.symlinkJoin {
            name = "all-packages";
            paths = map (name: pkgs.${name}) packageNames;
          };
          default = pkgs.opencode;
        });

      apps = forAllSystems (_system: { });

      nixosModules.openlogi = import ./modules/nixos/openlogi.nix;

      homeManagerModules.openlogi = import ./modules/home-manager/openlogi.nix;
    };
}
