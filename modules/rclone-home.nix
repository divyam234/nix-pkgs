{ lib, pkgs, config, ... }:

let
  common = import ./rclone-common.nix { inherit lib; };
  inherit (common) schema settingsType settingsEnvironment;

  cfg = config.programs.rclone;
  serviceCfg = config.services.rclone;

  globalEnvironment = settingsEnvironment cfg.settings // cfg.environment;

  instanceEnvironment = instance:
    globalEnvironment
    // settingsEnvironment instance.settings
    // instance.environment;

  commonInstanceOptions = {
    settings = lib.mkOption {
      type = settingsType;
      default = { };
      description = "Per-instance rclone settings overriding programs.rclone.settings.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables for this rclone user service.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional systemd EnvironmentFile for runtime secrets.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra command-line arguments appended to the rclone command.";
    };
  };

  mountType = lib.types.submodule ({ name, ... }: {
    options = commonInstanceOptions // {
      enable = lib.mkEnableOption "rclone mount ${name}";

      remote = lib.mkOption {
        type = lib.types.str;
        example = "media:";
        description = "rclone remote:path to mount.";
      };

      mountPoint = lib.mkOption {
        type = lib.types.str;
        example = "%h/mnt/media";
        description = "User mount point.";
      };
    };
  });

  serveType = lib.types.submodule ({ name, ... }: {
    options = commonInstanceOptions // {
      enable = lib.mkEnableOption "rclone serve instance ${name}";

      protocol = lib.mkOption {
        type = lib.types.enum [ "dlna" "docker" "ftp" "http" "nfs" "restic" "s3" "sftp" "webdav" ];
        description = "Protocol passed to rclone serve.";
      };

      remote = lib.mkOption {
        type = lib.types.str;
        example = "media:";
        description = "rclone remote:path to serve.";
      };
    };
  });

  rcdType = lib.types.submodule ({ name, ... }: {
    options = commonInstanceOptions // {
      enable = lib.mkEnableOption "rclone rcd instance ${name}";
    };
  });

  jobType = lib.types.submodule ({ name, ... }: {
    options = commonInstanceOptions // {
      enable = lib.mkEnableOption "rclone job ${name}";

      command = lib.mkOption {
        type = lib.types.str;
        example = "sync";
        description = "rclone subcommand to run.";
      };

      arguments = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "%h/Documents" "backup:documents" ];
        description = "Positional arguments passed after the rclone subcommand.";
      };

      onCalendar = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "daily";
        description = "Optional systemd OnCalendar schedule.";
      };

      persistent = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether a scheduled timer catches up after downtime.";
      };
    };
  });

  enabledMounts = lib.filterAttrs (_: value: value.enable) serviceCfg.mounts;
  enabledServe = lib.filterAttrs (_: value: value.enable) serviceCfg.serve;
  enabledRcd = lib.filterAttrs (_: value: value.enable) serviceCfg.rcd;
  enabledJobs = lib.filterAttrs (_: value: value.enable) serviceCfg.jobs;


  mountUsesAllowOther = instance:
    (cfg.settings."allow-other" or null) == true
    || (instance.settings."allow-other" or null) == true
    || lib.any
      (arg: arg == "--allow-other" || lib.hasPrefix "--allow-other=" arg)
      instance.extraArgs;

  fuseAllowOtherRequired =
    lib.any mountUsesAllowOther (builtins.attrValues enabledMounts);

  quoteArgs = args: lib.concatMapStringsSep " " lib.escapeShellArg args;

  envList = env:
    lib.mapAttrsToList (name: value: "${name}=${value}") env;

  environmentFiles = instance:
    lib.optional (instance.environmentFile != null) instance.environmentFile;


  mountEnvironment = instance:
    {
      PATH = "/run/wrappers/bin:/run/current-system/sw/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${lib.makeBinPath [ pkgs.fuse3 pkgs.coreutils ]}";
    }
    // instanceEnvironment instance;

  mountServices = lib.mapAttrs'
    (name: instance:
      lib.nameValuePair "rclone-mount-${name}" {
        Unit = {
          Description = "rclone mount ${name}";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };
        Service = {
          Type = "simple";
          Environment = envList (mountEnvironment instance);
          EnvironmentFile = environmentFiles instance;
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p -- ${lib.escapeShellArg instance.mountPoint}";
          ExecStart = "${cfg.package}/bin/rclone mount ${lib.escapeShellArg instance.remote} ${lib.escapeShellArg instance.mountPoint} ${quoteArgs instance.extraArgs}";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      })
    enabledMounts;

  serveServices = lib.mapAttrs'
    (name: instance:
      lib.nameValuePair "rclone-serve-${name}" {
        Unit = {
          Description = "rclone serve ${instance.protocol} (${name})";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };
        Service = {
          Type = "simple";
          Environment = envList (instanceEnvironment instance);
          EnvironmentFile = environmentFiles instance;
          ExecStart = "${cfg.package}/bin/rclone serve ${lib.escapeShellArg instance.protocol} ${lib.escapeShellArg instance.remote} ${quoteArgs instance.extraArgs}";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      })
    enabledServe;

  rcdServices = lib.mapAttrs'
    (name: instance:
      lib.nameValuePair "rclone-rcd-${name}" {
        Unit = {
          Description = "rclone remote control daemon (${name})";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };
        Service = {
          Type = "simple";
          Environment = envList (instanceEnvironment instance);
          EnvironmentFile = environmentFiles instance;
          ExecStart = "${cfg.package}/bin/rclone rcd ${quoteArgs instance.extraArgs}";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      })
    enabledRcd;

  jobServices = lib.mapAttrs'
    (name: instance:
      lib.nameValuePair "rclone-job-${name}" {
        Unit = {
          Description = "rclone job ${name}";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };
        Service = {
          Type = "oneshot";
          Environment = envList (instanceEnvironment instance);
          EnvironmentFile = environmentFiles instance;
          ExecStart = "${cfg.package}/bin/rclone ${lib.escapeShellArg instance.command} ${quoteArgs (instance.arguments ++ instance.extraArgs)}";
        };
      })
    enabledJobs;

  jobTimers = lib.mapAttrs'
    (name: instance:
      lib.nameValuePair "rclone-job-${name}" {
        Unit.Description = "Schedule rclone job ${name}";
        Timer = {
          OnCalendar = instance.onCalendar;
          Persistent = instance.persistent;
          Unit = "rclone-job-${name}.service";
        };
        Install.WantedBy = [ "timers.target" ];
      })
    (lib.filterAttrs (_: value: value.onCalendar != null) enabledJobs);
in
{

  options = {
    programs.rclone = {

      settings = lib.mkOption {
        type = settingsType;
        default = { };
        description = "Typed rclone settings exported as RCLONE_* session variables.";
      };

      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example.RCLONE_CONFIG_MEDIA_TYPE = "drive";
        description = "Additional global rclone environment variables.";
      };

      schema = lib.mkOption {
        type = lib.types.attrs;
        readOnly = true;
        default = schema;
        description = "Complete generated rclone schema.";
      };
    };

    services.rclone = {
      mounts = lib.mkOption {
        type = lib.types.attrsOf mountType;
        default = { };
        description = "Declarative user rclone mount services.";
      };

      serve = lib.mkOption {
        type = lib.types.attrsOf serveType;
        default = { };
        description = "Declarative user rclone serve services.";
      };

      rcd = lib.mkOption {
        type = lib.types.attrsOf rcdType;
        default = { };
        description = "Declarative user rclone RC daemon services.";
      };

      jobs = lib.mkOption {
        type = lib.types.attrsOf jobType;
        default = { };
        description = "Declarative one-shot or scheduled user rclone jobs.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home.sessionVariables = globalEnvironment;
      warnings = lib.optional fuseAllowOtherRequired ''
        rclone mount uses --allow-other. Home Manager cannot modify /etc/fuse.conf;
        enable user_allow_other on the host (on NixOS: programs.fuse.userAllowOther = true).
      '';
    })

    {
      assertions = [
        {
          assertion =
            enabledMounts == { }
            && enabledServe == { }
            && enabledRcd == { }
            && enabledJobs == { }
            || cfg.enable;
          message = "services.rclone requires programs.rclone.enable = true";
        }
        {
          assertion =
            pkgs.stdenv.hostPlatform.isLinux
            || (
              enabledMounts == { }
              && enabledServe == { }
              && enabledRcd == { }
              && enabledJobs == { }
            );
          message = "services.rclone in this module currently supports Linux/systemd user services only";
        }
        {
          assertion =
            lib.all
              (name: builtins.match "^[A-Za-z0-9_.-]+$" name != null)
              (
                builtins.attrNames enabledMounts
                ++ builtins.attrNames enabledServe
                ++ builtins.attrNames enabledRcd
                ++ builtins.attrNames enabledJobs
              );
          message = "services.rclone instance names may contain only letters, digits, '_', '-' and '.'";
        }
      ];

      systemd.user.services = mountServices // serveServices // rcdServices // jobServices;
      systemd.user.timers = jobTimers;
    }
  ];
}
