{ fetchurl, stdenvNoCC }:
let
  inherit (import ./release.nix) version sources;
  system = stdenvNoCC.hostPlatform.system;
  source = sources.${system} or (throw "tern is not packaged for ${system}");
in
{
  inherit version;
  src = fetchurl {
    url = "https://github.com/divyam234/nix-pkgs/releases/download/tern-v${version}/${source.asset}";
    inherit (source) hash;
  };
}
