{
  description = "Personal Nix package flake for newer GitHub release packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      overlays.default = final: prev: import ./pkgs { pkgs = final; inherit prev; };


      nixosModules.rclone = { lib, pkgs, ... }: {
        imports = [ ./modules/rclone.nix ];
        programs.rclone.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.rclone;
      };

      homeManagerModules.rclone = { lib, pkgs, ... }: {
        imports = [ ./modules/rclone-home.nix ];
        programs.rclone.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.rclone;
      };

      lib.rclone = import ./lib/rclone-schema.nix { lib = nixpkgs.lib; };

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

      checks = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };

          nixosTest = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.rclone
              {
                nixpkgs.overlays = [ self.overlays.default ];

                programs.rclone = {
                  enable = true;
                  settings.vfs-cache-mode = "full";
                };

                services.rclone = {
                  mounts.media = {
                    enable = true;
                    remote = "media:";
                    mountPoint = "/mnt/media";
                    settings.allow-other = true;
                  };

                  jobs.backup = {
                    enable = true;
                    command = "sync";
                    arguments = [ "/srv/data" "backup:data" ];
                    onCalendar = "daily";
                  };
                };
              }
            ];
          };

          homeTest = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              self.homeManagerModules.rclone
              {
                home.username = "rclone-test";
                home.homeDirectory = "/home/rclone-test";
                home.stateVersion = "25.05";

                programs.rclone = {
                  enable = true;
                  settings.vfs-cache-mode = "full";
                };

                services.rclone = {
                  mounts.media = {
                    enable = true;
                    remote = "media:";
                    mountPoint = "%h/mnt/media";
                  };

                  jobs.backup = {
                    enable = true;
                    command = "sync";
                    arguments = [ "%h/data" "backup:data" ];
                    onCalendar = "daily";
                  };
                };
              }
            ];
          };
        in
        {
          rclone-modules = pkgs.runCommand "rclone-modules-check" {
            nixosMount = nixosTest.config.systemd.services."rclone-mount-media".serviceConfig.ExecStart;
            nixosVfsMode = nixosTest.config.systemd.services."rclone-mount-media".environment.RCLONE_VFS_CACHE_MODE;
            nixosTimer = nixosTest.config.systemd.timers."rclone-job-backup".timerConfig.OnCalendar;
            nixosFuseAllowOther = if nixosTest.config.programs.fuse.userAllowOther then "true" else "false";
            homeMount = builtins.head homeTest.config.systemd.user.services."rclone-mount-media".Service.ExecStart;
            homeTimer = homeTest.config.systemd.user.timers."rclone-job-backup".Timer.OnCalendar;
          } ''
            test "$nixosVfsMode" = "full"
            test "$nixosTimer" = "daily"
            test "$homeTimer" = "daily"
            test "$nixosFuseAllowOther" = "true"
            case "$nixosMount" in
              *"rclone mount media: /mnt/media"*) ;;
              *) exit 1 ;;
            esac
            case "$homeMount" in
              *"rclone mount media: %h/mnt/media"*) ;;
              *) exit 1 ;;
            esac
            touch "$out"
          '';
        });

    };
}
