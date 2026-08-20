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
    in
    {
      overlays.default = final: prev: import ./pkgs { pkgs = final; inherit prev; };

      packages = forAllSystems (system:
        let
          prev = import nixpkgs { inherit system; };
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
          customPackages = import ./pkgs { inherit pkgs prev; };
          packageNames = builtins.attrNames customPackages;
        in
        customPackages // {
          all = pkgs.symlinkJoin {
            name = "all-packages";
            paths = map (name: customPackages.${name}) packageNames;
          };
          default = customPackages.opencode;
        });

      
    };
}
