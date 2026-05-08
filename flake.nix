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
        "ffmpeg"
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

      apps = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          updater = pkgs.writeShellApplication {
            name = "update-github-release";
            runtimeInputs = [
              pkgs.nix
              pkgs.python3
            ];
            text = ''
              python3 ${./lib/update-github-release.py} "$@"
            '';
          };

          updateApps = builtins.listToAttrs (map (name: {
            name = "update-${name}";
            value = {
              type = "app";
              program = "${pkgs.writeShellApplication {
                name = "update-${name}";
                runtimeInputs = [ updater ];
                text = ''
                  update-github-release pkgs/${name}/update.json
                '';
              }}/bin/update-${name}";
              meta.description = "Update ${name} from GitHub release metadata";
            };
          }) packageNames);

          updateAll = pkgs.writeShellApplication {
            name = "update-all";
            runtimeInputs = [ updater ];
            text = builtins.concatStringsSep "\n" (map (name: ''
              echo "==> updating ${name}"
              update-github-release pkgs/${name}/update.json
            '') packageNames);
          };
        in
        updateApps // {
          update-all = {
            type = "app";
            program = "${updateAll}/bin/update-all";
            meta.description = "Update every configured package";
          };
        });
    };
}
