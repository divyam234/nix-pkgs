# nix-pkgs

Personal Nix flake for newer packages that lag behind nixpkgs.

## Usage

Run a package directly:

```sh
nix run github:bhunter/nix-pkgs#opencode
```

Temporary shell with a package:

```sh
nix shell github:bhunter/nix-pkgs#ffmpeg
```

Install as a user package (Nix package manager):

```sh
nix profile install github:bhunter/nix-pkgs#rclone
```

Upgrade installed package:

```sh
nix profile upgrade rclone
```

Use the overlay in another flake:

```nix
{
  inputs.my-pkgs.url = "github:bhunter/nix-pkgs";

  outputs = { nixpkgs, my-pkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ my-pkgs.overlays.default ];
      };
    in
    {
      # pkgs.opencode is now available.
    };
}
```

### NixOS Configuration

Add this flake as an input in your system flake, then use its overlay:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    my-pkgs.url = "github:bhunter/nix-pkgs";
  };

  outputs = { nixpkgs, my-pkgs, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [ my-pkgs.overlays.default ];
          environment.systemPackages = with pkgs; [
            bun
            opencode
            ffmpeg
            rclone
            teldrive
          ];
        })
      ];
    };
  };
}
```

Apply:

```sh
sudo nixos-rebuild switch --flake .#my-host
```

### Home Manager Configuration

If you use Home Manager with flakes:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    my-pkgs.url = "github:bhunter/nix-pkgs";
  };

  outputs = { nixpkgs, home-manager, my-pkgs, ... }: {
    homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ my-pkgs.overlays.default ];
      };
      modules = [
        ({ pkgs, ... }: {
          home.packages = with pkgs; [
            bun
            opencode
            ffmpeg
            rclone
            teldrive
          ];
        })
      ];
    };
  };
}
```

Apply:

```sh
home-manager switch --flake .#me
```

## Packages

| Package | Source | Notes |
| --- | --- | --- |
| `bun` | `oven-sh/bun` GitHub releases | Linux `x86_64` and `aarch64` binaries |
| `ffmpeg` | `BtbN/FFmpeg-Builds` GitHub releases | FFmpeg 8.1 GPL shared Linux `x86_64` and `aarch64` binaries |
| `hydra` | `divyam234/hydra` GitHub releases | Linux `x86_64` and `aarch64` binaries |
| `opencode` | `anomalyco/opencode` GitHub releases | Linux `x86_64` and `aarch64` binaries |
| `rclone` | `tgdrive/rclone` GitHub releases | Linux `x86_64` and `aarch64` binaries |
| `teldrive` | `tgdrive/teldrive` GitHub releases | Linux `x86_64` and `aarch64` binaries |

## Updating Packages

Nix packages are pinned to exact versions and hashes. Update metadata is centralized in `updates.yml` and processed by `scripts/update-releases.py`.

```sh
uv run --with pyyaml python -B scripts/update-releases.py updates.yml --check --build
```

GitHub Actions runs `scripts/update-releases.py` daily and commits directly when package files change.

To add another GitHub release package:

1. Add `pkgs/<name>/default.nix`.
2. Add a package entry under `packages` in `updates.yml`.
3. Add the package name to `packageNames` in `flake.nix`.

### Template: single binary tarball

`pkgs/<name>/default.nix`:

```nix
{
  lib,
  githubReleaseBinary,
}:

let
  version = "1.2.3";

  sources = {
    x86_64-linux = {
      asset = "<name>-1.2.3-linux-amd64.tar.gz";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };

    aarch64-linux = {
      asset = "<name>-1.2.3-linux-arm64.tar.gz";
      hash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
    };
  };
in
githubReleaseBinary {
  inherit version sources;
  pname = "<name>";
  owner = "<org>";
  repo = "<repo>";

  binaryName = "<binary-in-archive>";

  meta = {
    description = "<description>";
    homepage = "https://github.com/<org>/<repo>";
    license = lib.licenses.mit;
    maintainers = [ ];
  };
}
```

`updates.yml` entry:

```yaml
packages:
  <name>:
    repo: <org>/<repo>
    file: pkgs/<name>/default.nix
    tagPrefix: v
    version:
      source: tag
    assets:
      x86_64-linux:
        pattern: '^<name>-v?[0-9]+\.[0-9]+\.[0-9]+-linux-amd64\.tar\.gz$'
      aarch64-linux:
        pattern: '^<name>-v?[0-9]+\.[0-9]+\.[0-9]+-linux-arm64\.tar\.gz$'
```

If upstream uses release names instead of semver tags, you can set:

```yaml
version:
  source: release-name-date
  prefix: 8.1-latest-
```

After editing the package, validate it:

```sh
nix flake check
nix build .#opencode
./result/bin/opencode --version
```
