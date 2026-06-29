{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.openlogi;
in
{
  options.hardware.openlogi = {
    enable = lib.mkEnableOption "OpenLogi HID++ device support";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.openlogi;
      defaultText = lib.literalExpression "pkgs.openlogi";
      description = "OpenLogi package to use";
    };
  };

  config = lib.mkIf cfg.enable {
    services.udev.packages = [ cfg.package ];

    environment.systemPackages = [ cfg.package ];
  };
}
