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
      description = "Additional environment variables for this rclone instance.";
    };


    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional EnvironmentFile for secrets or instance-specific rclone variables.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "User account used to run the rclone service.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Group used to run the rclone service.";
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
        example = "/mnt/media";
        description = "Local mount point.";
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
        example = [ "/srv/data" "backup:data" ];
        description = "Positional arguments passed after the rclone subcommand.";
      };

      onCalendar = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "daily";
        description = "Optional systemd OnCalendar schedule. Null creates only the service.";
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

  mountEnvironment = instance:
    {
      PATH = "/run/wrappers/bin:${lib.makeBinPath [ pkgs.fuse3 pkgs.coreutils ]}";
    }
    // instanceEnvironment instance;

  mountServices = lib.mapAttrs'
    (name: instance:
      lib.nameValuePair "rclone-mount-${name}" {
        description = "rclone mount ${name}";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        environment = mountEnvironment instance;
        serviceConfig = {
          Type = "simple";
          User = instance.user;
          Group = instance.group;
          ExecStartPre = "+${pkgs.coreutils}/bin/install -d -o ${lib.escapeShellArg instance.user} -g ${lib.escapeShellArg instance.group} -- ${lib.escapeShellArg instance.mountPoint}";
          EnvironmentFile = lib.optional (instance.environmentFile != null) instance.environmentFile;
          ExecStart = "${cfg.package}/bin/rclone mount ${lib.escapeShellArg instance.remote} ${lib.escapeShellArg instance.mountPoint} ${quoteArgs instance.extraArgs}";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      })
    enabledMounts;

  serveServices = lib.mapAttrs'
    (name: instance:
      lib.nameValuePair "rclone-serve-${name}" {
        description = "rclone serve ${instance.protocol} (${name})";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        environment = instanceEnvironment instance;
        serviceConfig = {
          Type = "simple";
          User = instance.user;
          Group = instance.group;
          EnvironmentFile = lib.optional (instance.environmentFile != null) instance.environmentFile;
          ExecStart = "${cfg.package}/bin/rclone serve ${lib.escapeShellArg instance.protocol} ${lib.escapeShellArg instance.remote} ${quoteArgs instance.extraArgs}";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      })
    enabledServe;

  rcdServices = lib.mapAttrs'
    (name: instance:
      lib.nameValuePair "rclone-rcd-${name}" {
        description = "rclone remote control daemon (${name})";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        environment = instanceEnvironment instance;
        serviceConfig = {
          Type = "simple";
          User = instance.user;
          Group = instance.group;
          EnvironmentFile = lib.optional (instance.environmentFile != null) instance.environmentFile;
          ExecStart = "${cfg.package}/bin/rclone rcd ${quoteArgs instance.extraArgs}";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      })
    enabledRcd;

  jobServices = lib.mapAttrs'
    (name: instance:
      lib.nameValuePair "rclone-job-${name}" {
        description = "rclone job ${name}";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        environment = instanceEnvironment instance;
        serviceConfig = {
          Type = "oneshot";
          User = instance.user;
          Group = instance.group;
          EnvironmentFile = lib.optional (instance.environmentFile != null) instance.environmentFile;
          ExecStart = "${cfg.package}/bin/rclone ${lib.escapeShellArg instance.command} ${quoteArgs (instance.arguments ++ instance.extraArgs)}";
        };
      })
    enabledJobs;

  jobTimers = lib.mapAttrs'
    (name: instance:
      lib.nameValuePair "rclone-job-${name}" {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = instance.onCalendar;
          Persistent = instance.persistent;
          Unit = "rclone-job-${name}.service";
        };
      })
    (lib.filterAttrs (_: value: value.onCalendar != null) enabledJobs);
in
{

  options = {
    programs.rclone = {
      enable = lib.mkEnableOption "rclone";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.rclone;
        defaultText = lib.literalExpression "pkgs.rclone";
        description = "rclone package to install and use for generated services.";
      };

      settings = lib.mkOption {
        type = settingsType;
        default = { };
        description = ''
          Typed rclone settings generated from the packaged rclone binary.
          Values are exported as RCLONE_* environment variables, so explicit
          command-line flags can still override them per invocation.
        '';
      };

      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = {
          RCLONE_CONFIG_MEDIA_TYPE = "drive";
        };
        description = ''
          Additional global rclone environment variables, including
          RCLONE_CONFIG_<REMOTE>_* remote configuration.
        '';
      };

      schema = lib.mkOption {
        type = lib.types.attrs;
        readOnly = true;
        default = schema;
        description = "Complete generated rclone schema, including flags and backend providers.";
      };
    };

    services.rclone = {
      mounts = lib.mkOption {
        type = lib.types.attrsOf mountType;
        default = { };
        description = "Declarative rclone mount services.";
      };

      serve = lib.mkOption {
        type = lib.types.attrsOf serveType;
        default = { };
        description = "Declarative rclone serve services.";
      };

      rcd = lib.mkOption {
        type = lib.types.attrsOf rcdType;
        default = { };
        description = "Declarative rclone remote-control daemon services.";
      };

      jobs = lib.mkOption {
        type = lib.types.attrsOf jobType;
        default = { };
        description = "Declarative one-shot or scheduled rclone commands.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = [ cfg.package ];
      environment.variables = globalEnvironment;
      programs.fuse.userAllowOther = lib.mkIf fuseAllowOtherRequired true;
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

      systemd.services = mountServices // serveServices // rcdServices // jobServices;
      systemd.timers = jobTimers;
    }
  ];
}
