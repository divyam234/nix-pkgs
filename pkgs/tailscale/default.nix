{
  lib,
  stdenv,
  fetchurl,
  makeBinaryWrapper,
  installShellFiles,
  getent,
  iproute2,
  iptables,
  kmod,
  shadow,
  procps,
}:

let
  version = "1.102.3";

  sources = {
    x86_64-linux = {
      arch = "amd64";
      hash = "sha256-Nt3ZtRvlf/wpkM92Mjz6E2Q7+7G4qWn2GD+hZHQc3vU=";
    };

    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-oPobFUr4xh+GKiJZ9Vn3OW2WwCJfSoY+riMz4VRrviU=";
    };
  };

  source = sources.${stdenv.hostPlatform.system} or (throw "tailscale is not packaged for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "tailscale";
  inherit version;

  src = fetchurl {
    url = "https://pkgs.tailscale.com/stable/tailscale_${version}_${source.arch}.tgz";
    inherit (source) hash;
  };

  sourceRoot = "tailscale_${version}_${source.arch}";

  nativeBuildInputs = [
    makeBinaryWrapper
    installShellFiles
  ];

  dontConfigure = true;
  dontBuild = true;
  # Binaries are statically linked Go executables (no .dynamic section),
  # so there is nothing for patchelf/strip to do.
  dontStrip = true;
  dontPatchELF = true;
  noAuditTmpdir = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 tailscale $out/bin/tailscale
    install -Dm755 tailscaled $out/bin/tailscaled

    # Emulate nixpkgs pkgs/by-name/ta/tailscale/package.nix:
    # patch hardcoded /usr/sbin out of the upstream unit and drop the
    # EnvironmentFile line (Nix store has no /etc/default/tailscaled).
    sed -i -e "s#/usr/sbin#$out/bin#" -e "/^EnvironmentFile/d" ./systemd/tailscaled.service
    # wait-online unit hardcodes /usr/bin/tailscale, point it at the store too.
    sed -i -e "s#/usr/bin#$out/bin#" ./systemd/tailscale-wait-online.service

    install -D -m0444 -t $out/lib/systemd/system ./systemd/tailscaled.service
    install -D -m0444 -t $out/lib/systemd/system ./systemd/tailscale-wait-online.service
    install -D -m0444 -t $out/lib/systemd/system ./systemd/tailscale-online.target
    install -D -m0444 ./systemd/tailscaled.defaults $out/share/doc/tailscale/tailscaled.defaults.example

    runHook postInstall
  '';

  postFixup = ''
    # Runtime PATH mirrors nixpkgs' tailscale package (getent, iproute2,
    # iptables, shadow, procps) plus kmod, which the NixOS module adds
    # for tailscale's v6nat check.
    wrapProgram $out/bin/tailscaled \
      --prefix PATH : ${
        lib.makeBinPath [
          getent
          iproute2
          iptables
          kmod
          shadow
        ]
      } \
      --suffix PATH : ${lib.makeBinPath [ procps ]}
  '';

  postInstall = ''
    installShellCompletion --cmd tailscale \
      --bash <($out/bin/tailscale completion bash) \
      --fish <($out/bin/tailscale completion fish) \
      --zsh <($out/bin/tailscale completion zsh)
  '';

  meta = {
    description = "Node agent for Tailscale, a mesh VPN built on WireGuard (prebuilt)";
    homepage = "https://tailscale.com";
    changelog = "https://tailscale.com/changelog#client";
    license = lib.licenses.bsd3;
    maintainers = [ ];
    platforms = builtins.attrNames sources;
    mainProgram = "tailscale";
  };
}
