{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  patchelf,
  wayland,
  wlroots_0_20,
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
    cp -r bin share $out/ 2>/dev/null || true
    # also handle usr/bin layout if tar was created with usr prefix
    if [ -d usr/bin ]; then
      mkdir -p $out/bin
      cp -r usr/bin/* $out/bin/ 2>/dev/null || true
    fi
    if [ -d usr/share ]; then
      mkdir -p $out/share
      cp -r usr/share/* $out/share/ 2>/dev/null || true
    fi

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
