{ lib }:

let
  schema = builtins.fromJSON (builtins.readFile ../modules/rclone/generated-schema.json);
in
{
  inherit schema;

  flags = schema.flags;
  providers = schema.providers;
  optionBlocks = schema.optionBlocks;

  flagNames = builtins.attrNames schema.flags;
  providerNames = builtins.attrNames schema.providers;

  hasFlag = name: builtins.hasAttr name schema.flags;
  hasProvider = name: builtins.hasAttr name schema.providers;

  providerOptions = name:
    if builtins.hasAttr name schema.providers
    then schema.providers.${name}.options
    else throw "unknown rclone provider: ${name}";
}
