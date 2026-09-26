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

  renderFlag = name: value:
    if value == null then [ ]
    else if builtins.isBool value then
      [ "--${name}=${if value then "true" else "false"}" ]
    else if builtins.isList value then
      map (item: "--${name}=${toString item}") value
    else
      [ "--${name}=${toString value}" ];

  configuredFlags = lib.concatLists (lib.mapAttrsToList renderFlag cfg.flags) ++ cfg.extraFlags;

  wrappedRclone = pkgs.symlinkJoin {
    name = "rclone-configured-${cfg.package.version}";
    paths = [ cfg.package ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/rclone" \
        ${lib.concatMapStringsSep " " (arg: "--add-flags ${lib.escapeShellArg arg}") configuredFlags}
    '';
  };
in
{
  options.programs.rclone = {
    enable = lib.mkEnableOption "rclone";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.rclone;
      defaultText = lib.literalExpression "pkgs.rclone";
      description = "rclone package to install and wrap.";
    };

    flags = lib.mkOption {
      type = lib.types.submodule { options = flagOptions; };
      default = { };
      description = "Typed rclone flags generated from the packaged rclone binary.";
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--future-flag=value" ];
      description = "Additional raw flags for forward compatibility.";
    };

    schema = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = schema;
      description = "Complete generated rclone schema, including flags and backend providers.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ wrappedRclone ];
  };
}
