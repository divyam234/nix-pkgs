# nix-pkgs

Personal Nix flake for packages newer than nixpkgs.

## Use

```sh
nix run github:divyam234/nix-pkgs#rclone
nix profile install github:divyam234/nix-pkgs#rclone
```

Replace `rclone` with any package below.

## Packages

`aria2`, `brave`, `bun`, `codeforge`,
`foliate`, `hydra`, `mcontrolcenter`, `nordvpn`, `opencode`,
`rclone`, `restic`, `sublime`, `teldrive`, `zed-editor`, `zjstatus`.


## Rclone Nix schema

The flake exports `nixosModules.rclone` and `lib.rclone`. The schema is generated from the packaged rclone binary using `options/info`, `config/providers`, and `help flags`, and is regenerated automatically when the rclone package updater changes versions.

```nix
{
  imports = [ inputs.customPkgs.nixosModules.rclone ];
  nixpkgs.overlays = [ inputs.customPkgs.overlays.default ];

  programs.rclone = {
    enable = true;
    flags = {
      checkers = 16;
      transfers = 8;
      vfs-cache-mode = "full";
    };
  };
}
```

Raw schema metadata is available as `inputs.customPkgs.lib.rclone.schema`, including all generated flags, providers, and option blocks.


Configured values are exported as `RCLONE_*` environment variables instead of wrapping the binary, so explicit CLI flags still take precedence. Remote-specific variables can be supplied with `programs.rclone.environment`.

## Update

```sh
./scripts/update-all.sh --check --build
```
