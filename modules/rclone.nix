{ lib, pkgs, config, ... }:

let
  schema = builtins.fromJSON (builtins.readFile ./rclone/generated-schema.json);
  cfg = config.programs.rclone;

  normalizeType = raw:
    let t = lib.toLower raw;
    in
      if lib.elem t [ "bool" "boolean" ] then lib.types.bool
      else if lib.elem t [ "int" "int32" "int64" "uint" "uint32" "uint64" "count" ] then lib.types.int
      else if lib.elem t [ "float" "float32" "float64" ] then lib.types.number
      else if lib.elem t [ "stringarray" "strings" ] then lib.types.listOf lib.types.str
      else lib.types.str;

  flagOptions = lib.mapAttrs
    (name: meta: lib.mkOption {
      type = lib.types.nullOr (normalizeType (meta.type or "string"));
      default = null;
      description = meta.help or "rclone flag --${name}";
    })
    schema.flags;

  envName = name:
    "RCLONE_" + lib.toUpper (builtins.replaceStrings [ "-" ] [ "_" ] name);

  envValue = value:
    if builtins.isBool value then
      if value then "true" else "false"
    else if builtins.isList value then
      lib.concatStringsSep "," (map toString value)
    else
      toString value;

  generatedEnvironment = lib.mapAttrs'
    (name: value: lib.nameValuePair (envName name) (envValue value))
    (lib.filterAttrs (_: value: value != null) cfg.flags);
in
{
  options.programs.rclone = {
    enable = lib.mkEnableOption "rclone";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.rclone;
      defaultText = lib.literalExpression "pkgs.rclone";
      description = "rclone package to install.";
    };

    flags = lib.mkOption {
      type = lib.types.submodule { options = flagOptions; };
      default = { };
      description = ''
        Typed rclone options generated from the packaged rclone binary.
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
        Additional rclone environment variables. These are merged over the
        generated RCLONE_* variables and can be used for remote-specific
        RCLONE_CONFIG_<REMOTE>_* settings or forward-compatible options.
      '';
    };

    schema = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = schema;
      description = "Complete generated rclone schema, including flags and backend providers.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.variables = generatedEnvironment // cfg.environment;
  };
}
