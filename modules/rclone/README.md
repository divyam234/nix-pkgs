# Rclone modules

This directory contains the generated rclone schema and the NixOS/Home Manager integration built around it.

The flake exports:

- `nixosModules.rclone` for NixOS.
- `homeManagerModules.rclone` for Home Manager.
- `lib.rclone` for direct access to the generated schema.

The schema is generated from the packaged rclone binary using `options/info`, `config/providers`, and `help flags`. It is regenerated automatically when the packaged rclone version changes.

Generated settings are typed Nix options, including detected enums, and are rendered as `RCLONE_*` environment variables. This keeps the normal rclone binary untouched and lets explicit CLI flags override module defaults.

The exported modules default `programs.rclone.package` to this flake's rclone package, so the runtime binary and generated schema stay version-aligned unless you explicitly override the package.

## NixOS

```nix
{
  imports = [
    inputs.nix-pkgs.nixosModules.rclone
  ];


  programs.rclone = {
    enable = true;

    settings = {
      transfers = 8;
      checkers = 16;

      vfs-cache-mode = "full";
      vfs-cache-max-size = "500Gi";
      vfs-read-ahead = "512Mi";

      log-level = "INFO";
    };

    environment = {
      RCLONE_CONFIG_MEDIA_TYPE = "drive";
    };
  };

  services.rclone = {
    mounts.media = {
      enable = true;
      remote = "media:";
      mountPoint = "/mnt/media";

      user = "media";
      group = "media";

      settings = {
        vfs-cache-max-size = "1Ti";
      };

      environmentFile = "/run/secrets/rclone-media.env";
    };

    serve.webdav = {
      enable = true;
      protocol = "webdav";
      remote = "media:";

      settings = {
        webdav-addr = "127.0.0.1:8080";
      };
    };

    rcd.main = {
      enable = true;

      settings = {
        rc-addr = "127.0.0.1:5572";
      };
    };

    jobs.backup = {
      enable = true;
      command = "sync";
      arguments = [
        "/srv/data"
        "backup:data"
      ];

      onCalendar = "daily";
      persistent = true;
    };
  };
}
```

This creates ordinary systemd units such as:

```text
rclone-mount-media.service
rclone-serve-webdav.service
rclone-rcd-main.service
rclone-job-backup.service
rclone-job-backup.timer
```

Every service inherits `programs.rclone.settings` and `programs.rclone.environment`, then applies its own `settings` and `environment` overrides.

## Home Manager

Home Manager already includes its own `programs.rclone` module for remote definitions. This flake extends it with the generated typed `settings` schema and adds matching user-level `services.rclone` units.

```nix
{
  imports = [
    inputs.nix-pkgs.homeManagerModules.rclone
  ];

  programs.rclone = {
    enable = true;

    remotes.media = {
      config = {
        type = "drive";
      };

      secrets.token = config.age.secrets.rclone-token.path;
    };

    settings = {
      transfers = 8;
      checkers = 16;
      vfs-cache-mode = "full";
      log-level = "INFO";
    };
  };

  services.rclone = {
    mounts.media = {
      enable = true;
      remote = "media:";
      mountPoint = "%h/mnt/media";

      settings = {
        vfs-cache-max-size = "250Gi";
      };
    };

    serve.http = {
      enable = true;
      protocol = "http";
      remote = "media:";

      settings = {
        http-addr = "127.0.0.1:8080";
      };
    };

    rcd.main = {
      enable = true;
      settings.rc-addr = "127.0.0.1:5572";
    };

    jobs.documents = {
      enable = true;
      command = "sync";
      arguments = [
        "%h/Documents"
        "media:Documents"
      ];
      onCalendar = "hourly";
    };
  };
}
```

Home Manager services are emitted as `systemd --user` units and currently support Linux only. The existing Home Manager remote/config generation remains in use; this module only extends it.

## Schema access

Raw schema metadata is available at:

```nix
inputs.nix-pkgs.lib.rclone.schema
inputs.nix-pkgs.lib.rclone.flags
inputs.nix-pkgs.lib.rclone.providers
inputs.nix-pkgs.lib.rclone.optionBlocks
```
