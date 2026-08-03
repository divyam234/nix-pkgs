{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  patchelf,
  wayland,
  wayland-protocols,
  libGL,
  libglvnd,
  freetype,
  fontconfig,
  cairo,
  pango,
  harfbuzz,
  libxkbcommon,
  sdbus-cpp_2,
  systemd,
  pipewire,
  pam,
  curl,
  libwebp,
  glib,
  polkit,
  librsvg,
  libqalculate,
  libxml2_13,
  md4c,
  stb,
  nlohmann_json,
  tomlplusplus,
  wireplumber,
  jemalloc,
  libsecret,
  libsodium,
  libical,
  libjxl,
  libsndfile,
}:

let
  version = "5.0.0-beta.5";

  sources = {
    x86_64-linux = {
      asset = "noctalia-v${version}-linux-amd64.tar.gz";
      hash = "sha256-6BnLAD7OBpL/qA28J8liQlSLt3PHB4x0cYxYOss4+mU=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "noctalia is not packaged for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "noctalia";
  inherit version;

  src = fetchurl {
    url = "https://github.com/divyam234/nix-pkgs/releases/download/noctalia-v${version}/${source.asset}";
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
    wayland-protocols
    libGL
    libglvnd
    freetype
    fontconfig
    cairo
    pango
    harfbuzz
    libxkbcommon
    sdbus-cpp_2
    systemd
    pipewire
    pam
    curl
    libxml2_13
    libwebp
    glib
    polkit
    librsvg
    libqalculate
    md4c
    stb
    nlohmann_json
    tomlplusplus
    wireplumber
    jemalloc
    libsecret
    libsodium
    libical
    libjxl
    libsndfile
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/noctalia "$out/bin/noctalia"
    cp -r share "$out/"

    runHook postInstall
  '';
  preFixup = ''
    patchelf --replace-needed libsodium.so.23 libsodium.so.26 "$out/bin/noctalia"
  '';
  meta = {
    description = "A lightweight Wayland shell and bar built directly on Wayland and OpenGL ES";
    homepage = "https://github.com/noctalia-dev/noctalia";
    license = lib.licenses.mit;
    mainProgram = "noctalia";
    platforms = builtins.attrNames sources;
  };
}
