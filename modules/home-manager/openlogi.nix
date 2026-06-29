{ config, lib, pkgs, ... }:

let
  cfg = config.services.openlogi;

  configTOML = pkgs.writeText "openlogi-config.toml" (
    lib.generators.toTOML {} cfg.settings
  );
in
{
  meta.maintainers = [ ];

  options.services.openlogi = {
    enable = lib.mkEnableOption "OpenLogi background agent";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.openlogi;
      defaultText = lib.literalExpression "pkgs.openlogi";
      description = "OpenLogi package to use";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        OpenLogi configuration as an attribute set.
        Will be serialized to TOML at {file}`~/.config/openlogi/config.toml`.
      '';
      example = {
        profiles = [
          {
            name = "Default";
            dpi = 1600;
            buttons = {
              Button_4 = "Back";
              Button_5 = "Forward";
            };
          }
        ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file.".config/openlogi/config.toml" = lib.mkIf (cfg.settings != { }) {
      source = configTOML;
    };

    systemd.user.services.openlogi-agent = {
      Unit = {
        Description = "OpenLogi background agent (Logitech HID++ device control)";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/openlogi-agent";
        Restart = "on-failure";
        RestartSec = "5";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
