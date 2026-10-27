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
`rclone`, `restic`, `sublime`, `tern`, `tusk`, `vlc4`, `zed-editor`, `zjstatus`.

`nix build .#all` excludes VLC to avoid its lengthy source build in CI.
Build it explicitly with `nix build .#vlc4`.


## Rclone modules

NixOS and Home Manager rclone module documentation is in [modules/rclone/README.md](modules/rclone/README.md).

## Update

```sh
./scripts/update-all.sh
```

Updates flake inputs and package versions/hashes without bulk validation builds.
The scheduled package updater does the same. Rclone schema regeneration still
builds rclone when its version changes, keeping the module options in sync.
Validation remains opt-in:

```sh
./scripts/update-all.sh --check --build --smoke-test
```

`--build` builds changed packages, including VLC if it changed. To validate only
selected packages, invoke `scripts/update-releases.py` directly with their names.

NordVPN and rclone publishing workflows run daily. Manual runs support `force`
to rebuild existing releases; scheduled runs always use `force: false`.
