# nix-pkgs

Personal Nix flake for packages newer than nixpkgs.

## Use

```sh
nix run github:divyam234/nix-pkgs#rclone
nix profile install github:divyam234/nix-pkgs#rclone
```

Replace `rclone` with any package below.

## Packages

`aria2`, `beekeeper-studio`, `brave`, `bun`, `codeforge`, `dbeaver-bin`,
`foliate`, `hydra`, `mcontrolcenter`, `niri`, `nordvpn`, `opencode`, `openlogi`,
`rclone`, `sublime`, `teldrive`, `zed-editor`, `zjstatus`.

## Update

```sh
./scripts/update-all.sh --check --build
```
