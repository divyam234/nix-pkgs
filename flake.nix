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
        "bun"
        "opencode"
        "rclone"
        "teldrive"
      ];
    in
    {
      overlays.default = final: _prev: import ./pkgs { pkgs = final; };

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
    };
}
