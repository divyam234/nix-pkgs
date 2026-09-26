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


## Rclone modules

NixOS and Home Manager rclone module documentation is in [modules/rclone/README.md](modules/rclone/README.md).

## Update

```sh
./scripts/update-all.sh --check --build
```
