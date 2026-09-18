{
  lib,
  stdenv,
  fetchurl,
  bzip2,
  makeBinaryWrapper,
  installShellFiles,
  openssh,
  rclone,
}:

let
  version = "0.19.1";

  sources = {
    x86_64-linux = {
      asset = "restic_0.19.1_linux_amd64.bz2";
      hash = "sha256-9BVBViTcxFLyoCuMM2QXkajG1tO2W7s1Q/z5olFRWFw=";
    };

    aarch64-linux = {
      asset = "restic_0.19.1_linux_arm64.bz2";
      hash = "sha256-pfZKqrU9UeMR+jgpEkxbcD8tFM8YfYZAtr47K0k3ZGU=";
    };
  };

  source = sources.${stdenv.hostPlatform.system} or (throw "restic is not packaged for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "restic";
  inherit version;

  src = fetchurl {
    url = "https://github.com/restic/restic/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  nativeBuildInputs = [
    bzip2
    makeBinaryWrapper
    installShellFiles
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    bunzip2 --stdout "$src" > restic
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 restic "$out/bin/restic"
    runHook postInstall
  '';

  postInstall = ''
    wrapProgram $out/bin/restic \
      --prefix PATH : "${
        lib.makeBinPath [
          openssh
          rclone
        ]
      }"
  ''
  + lib.optionalString (stdenv.hostPlatform == stdenv.buildPlatform) ''
    $out/bin/restic generate \
      --bash-completion restic.bash \
      --fish-completion restic.fish \
      --zsh-completion restic.zsh \
      --man .
    installShellCompletion restic.{bash,fish,zsh}
    installManPage *.1
  '';

  meta = {
    description = "Backup program that is fast, efficient and secure";
    homepage = "https://restic.net";
    changelog = "https://github.com/restic/restic/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.bsd2;
    mainProgram = "restic";
    platforms = builtins.attrNames sources;
    maintainers = [ ];
  };
}
