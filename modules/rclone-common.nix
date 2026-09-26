{ lib }:

let
  schema = builtins.fromJSON (builtins.readFile ./rclone/generated-schema.json);

  normalizeType = raw:
    let t = lib.toLower raw;
    in
      if lib.elem t [ "bool" "boolean" ] then lib.types.bool
      else if lib.elem t [ "int" "int32" "int64" "uint" "uint32" "uint64" "count" ] then lib.types.int
      else if lib.elem t [ "float" "float32" "float64" ] then lib.types.number
      else if lib.elem t [ "stringarray" "strings" ] then lib.types.listOf lib.types.str
      else lib.types.str;

  optionType = meta:
    if meta ? enum && meta.enum != [ ] then lib.types.enum meta.enum
    else normalizeType (meta.type or "string");

  flagOptions = lib.mapAttrs
    (name: meta: lib.mkOption {
      type = lib.types.nullOr (optionType meta);
      default = null;
      description = meta.help or "rclone option --${name}";
    })
    schema.flags;

  settingsType = lib.types.submodule {
    options = flagOptions;
  };

  envName = name:
    "RCLONE_" + lib.toUpper (builtins.replaceStrings [ "-" ] [ "_" ] name);

  envValue = value:
    if builtins.isBool value then
      if value then "true" else "false"
    else if builtins.isList value then
      lib.concatStringsSep "," (map toString value)
    else
      toString value;

  settingsEnvironment = settings:
    lib.mapAttrs'
      (name: value: lib.nameValuePair (envName name) (envValue value))
      (lib.filterAttrs (_: value: value != null) settings);
in
{
  inherit
    schema
    settingsType
    settingsEnvironment
    ;
}
