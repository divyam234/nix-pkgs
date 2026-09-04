{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  patchelf,
  wayland,
  wlroots_0_20,
  libinput,
  libGL,
  libglvnd,
  freetype,
  fontconfig,
  cairo,
  pango,
  harfbuzz,
  libxkbcommon,
  glib,
  libwebp,
  librsvg,
}:

let
  version = "1.3.1";

  sources = {
    x86_64-linux = {
      asset = "noctalia-greeter-v${version}-linux-amd64.tar.gz";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "noctalia-greeter is not packaged for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "noctalia-greeter";
  inherit version;

  src = fetchurl {
    url = "https://github.com/divyam234/nix-pkgs/releases/download/noctalia-greeter-v${version}/${source.asset}";
    inherit (source) hash;
  };

  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  nativeBuildInputs = [
    autoPatchelfHook
    patchelf
  ];

  buildInputs = [
    wayland
    wlroots_0_20
    libinput
    libGL
    libglvnd
    freetype
    fontconfig
    cairo
    pango
    harfbuzz
    libxkbcommon
    glib
    libwebp
    librsvg
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    for dir in bin share lib; do
      if [ -d "$dir" ]; then
        cp -a "$dir" $out/
      fi
    done

    test -x $out/bin/noctalia-greeter
    test -x $out/bin/noctalia-greeter-compositor
    test -x $out/bin/noctalia-greeter-session
    test -x $out/bin/noctalia-greeter-apply-appearance
    test -x $out/bin/noctalia-greeter-print-greetd-config
    test -d $out/share/noctalia-greeter/assets

    runHook postInstall
  '';

  meta = {
    description = "A greetd greeter tightly coupled with Noctalia (prebuilt)";
    homepage = "https://github.com/noctalia-dev/noctalia-greeter";
    license = lib.licenses.mit;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "noctalia-greeter";
  };
}
