{
  lib,
  stdenvNoCC,
  fetchurl,
  gpuiApp,
  installShellFiles,
  glib,
  glib-networking,
  libpulseaudio,
  pipewire,
  python3,
  webkitgtk_4_1,
  wrapGAppsHook3,
  zenity,
}:

let
  version = "0.9.13";

  # Only x86_64-linux: release preparation patches the startup login flow
  # (see scripts/patch-tern-gate.py), and the patch fingerprints
  # currently cover the x86_64 build only.
  sources = {
    x86_64-linux = {
      asset = "Tern-0.9.13-linux-x86_64.tar.gz";
      hash = "sha256-oeoXphjxHLmFXkpO2VUJHxi5mrTsvD3Xq70kuyQWYvk=";
    };
  };

  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "tern is not packaged for ${stdenvNoCC.hostPlatform.system}");
in
gpuiApp {
  pname = "tern";
  inherit version;

  src = fetchurl {
    url = "https://github.com/divyam234/nix-pkgs/releases/download/tern-v${version}/${source.asset}";
    inherit (source) hash;
  };

  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  binaryPath = "bin/tern";
  nativeBuildInputs = [
    installShellFiles
    python3
    wrapGAppsHook3
  ];
  buildInputs = [
    glib-networking
    libpulseaudio
    pipewire
    webkitgtk_4_1
  ];
  # gpuiApp owns the GPUI wrapper; add the GTK/GIO environment afterward.
  dontWrapGApps = true;
  postFixup = ''
    wrapProgram "$out/bin/tern" "''${gappsWrapperArgs[@]}"
  '';
  extraWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [
      glib.bin
      zenity
    ])
    # Never phone home: the omp management offer is patched out, so the
    # build service is unreachable by design. The sign-in card is
    # non-blocking, but pointing the auth service at a dead address makes
    # any residual check fail fast instead of hitting the network.
    # --set-default keeps them overridable via the environment.
    "--set-default"
    "TERN_AUTH_URL"
    "http://127.0.0.1:9"
    "--set-default"
    "TERN_BUILD_URL"
    "http://127.0.0.1:9"
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 tern/tern "$out/bin/tern"

    # The release embeds its shell adapters rather than shipping separate files.
    # Extract them from this build so completions track the packaged version.
    python3 - "$out/bin/tern" <<'PY'
    import mmap
    from pathlib import Path
    import sys
    import textwrap

    executable = sys.argv[1]
    with open(executable, "rb") as binary, mmap.mmap(binary.fileno(), 0, access=mmap.ACCESS_READ) as data:
        def extract(start, end):
            first = data.find(start)
            if first == -1:
                raise RuntimeError(f"Tern completion adapter not found: {start!r}")
            last = data.find(end, first + len(start))
            if last == -1:
                raise RuntimeError(f"Tern completion adapter end not found: {end!r}")
            return data[first:last + len(end)].decode("utf-8")

        bash = textwrap.dedent(extract(b"\t_ksi_tern() {\n", b"\n\t}\n"))
        bash = bash.replace("_ksi_tern()", "_tern()")
        bash = bash.replace('"$TERN_EXE"', f'"{executable}"')
        Path("tern.bash").write_text(bash + "complete -F _tern tern\n")

        zsh = extract(b"\n_ksi_tern() {\n", b"\n}\n")
        zsh = zsh.replace("_ksi_tern()", "_tern()")
        zsh = zsh.replace('"$TERN_EXE"', f'"{executable}"')
        Path("_tern").write_text('#compdef tern\n' + zsh + '\n_tern "$@"\n')

        fish = extract(
            b"function __ksi_tern_complete --description",
            b"complete --command tern --no-files --arguments '(__ksi_tern_complete)'",
        )
        fish = fish.replace('\ttest -n "$TERN_EXE"; or return\n', "")
        fish = fish.replace("$TERN_EXE", f'"{executable}"')
        fish = fish.replace("__ksi_tern_complete", "__tern_complete")
        Path("tern.fish").write_text(fish + "\n")
    PY
    installShellCompletion --cmd tern tern.bash _tern tern.fish

    install -Dm644 ${./tern.desktop} "$out/share/applications/tern.desktop"
    substituteInPlace "$out/share/applications/tern.desktop" \
      --replace-fail 'Exec=tern' "Exec=$out/bin/tern"
    install -Dm644 ${./tern.png} \
      "$out/share/icons/hicolor/512x512/apps/tern.png"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    "$out/bin/tern" --version
  '';

  meta = {
    description = "AI-native terminal with persistent sessions";
    homepage = "https://stencil.so";
    mainProgram = "tern";
    platforms = [ "x86_64-linux" ];
  };
}
