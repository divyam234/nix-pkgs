# nix-pkgs

Personal Nix flake for packages newer than nixpkgs.

## Use

```sh
nix run github:divyam234/nix-pkgs#rclone
nix profile install github:divyam234/nix-pkgs#rclone
```

Replace `rclone` with any package below.

## Packages

`aria2`, `brave`, `bun`, `codeforge`, `disktree`,
`fluxdown`, `foliate`, `hydra`, `mcontrolcenter`, `nordvpn`, `opencode`, `pdfcraft`, `probe`,
`rclone`, `restic`, `sublime`, `tern`, `tusk`, `zed-editor`, `zjstatus`.


## Rclone modules

NixOS and Home Manager rclone module documentation is in [modules/rclone/README.md](modules/rclone/README.md).

## Update

```sh
./scripts/update-all.sh --check --build
```

NordVPN and rclone publishing workflows run daily. Manual runs support `force`
to rebuild existing releases; scheduled runs always use `force: false`.
