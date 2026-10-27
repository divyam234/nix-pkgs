# VLC 4.0 development tree with the Juxtopposed interface redesign.
# Based on https://github.com/iankengott/vlc-redesign-nix package.nix.
# Source: https://github.com/dsojevic/juxtopposed-vlc (GPLv2+ code, CC BY 4.0 design)
# The fork moves quickly; updates are tracked from the repo head and fetched
# as tar archives so the hash comes from the standard prefetch flow.
{
  lib,
  stdenv,
  fetchurl,
  meson,
  ninja,
  pkg-config,
  python3,
  flex,
  bison,
  gettext,
  lua5_2_compat,
  unzip,
  wayland-scanner,
  spirv-tools,
  qt6,
  kdePackages,
  wrapGAppsHook3,
  patchelf,
  makeWrapper,
  runCommand,
  symlinkJoin,
  alsa-lib,
  avahi,
  cairo,
  dbus,
  faad2,
  ffmpeg_9,
  flac,
  fontconfig,
  freefont_ttf,
  freetype,
  fribidi,
  gnutls,
  harfbuzz,
  libGL,
  libarchive,
  libass,
  libbluray,
  libcddb,
  libdvbpsi,
  libdvdnav,
  libebml,
  libgcrypt,
  libgpg-error,
  libjpeg,
  libmatroska,
  libogg,
  libopus,
  libplacebo,
  libpng,
  libpulseaudio,
  librsvg,
  libsamplerate,
  libssh2,
  libtheora,
  libva,
  libvorbis,
  libxml2,
  libxcb,
  libxcb-keysyms,
  libxkbcommon,
  libx11,
  libxext,
  libxinerama,
  libxpm,
  libsm,
  live555,
  ncurses,
  samba,
  speex,
  srt,
  systemdLibs,
  taglib,
  wayland,
  wayland-protocols,
  zlib,
}:

let
  vlc = stdenv.mkDerivation (finalAttrs: {
    pname = "vlc";
    version = "4.0.0-beta.5";
    rev = "958859ebb3f02e526fc0ec8f99336434e6143739";

  src = fetchurl {
    url = "https://github.com/dsojevic/juxtopposed-vlc/archive/${finalAttrs.rev}.tar.gz";
    hash = "sha256-UOie2c251QOoU1tFDCxuDMsu6Xl/jGjheaCVn/ufU1w=";
  };

  sourceRoot = "juxtopposed-vlc-${finalAttrs.rev}";

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    python3
    flex
    bison
    gettext
    lua5_2_compat
    unzip
    wayland-scanner
    # Let qsb find spirv-opt so the Qt shaders get optimized.
    spirv-tools
    qt6.wrapQtAppsHook
    qt6.qttools
    wrapGAppsHook3
    patchelf
  ];

  buildInputs = [
    alsa-lib
    avahi
    cairo
    dbus
    faad2
    ffmpeg_9
    flac
    fontconfig
    freetype
    fribidi
    gnutls
    harfbuzz
    libGL
    libarchive
    libass
    libbluray
    libcddb
    libdvbpsi
    libdvdnav
    libdvdnav.libdvdread
    libebml
    libgcrypt
    libgpg-error
    libjpeg
    libmatroska
    libogg
    libopus
    libplacebo
    libpng
    libpulseaudio
    librsvg
    libsamplerate
    libssh2
    libtheora
    libva
    libvorbis
    libxml2
    libxcb
    libxcb-keysyms
    libxkbcommon
    libx11
    libxext
    libxinerama
    libxpm
    libsm
    live555
    lua5_2_compat
    ncurses
    samba
    speex
    srt
    systemdLibs
    taglib
    wayland
    wayland-protocols
    zlib
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtsvg
    qt6.qtwayland
    qt6.qt5compat
    qt6.qtshadertools
    kdePackages.kwindowsystem
  ];

  strictDeps = true;
  dontWrapGApps = true; # Qt wrapper adds the gapps args below

  postPatch = ''
    patchShebangs buildsystem
    substituteInPlace modules/text_renderer/freetype/platform_fonts.h \
      --replace-fail \
        /usr/share/fonts/truetype/freefont \
        ${freefont_ttf}/share/fonts/truetype
  '';

  # nixpkgs defaults to auto_features=enabled, which makes optional probes
  # (AArch64 branch protection, every optional codec) hard errors.
  mesonAutoFeatures = "auto";

  mesonFlags = [
    "-Drust=disabled"
    "-Dchromecast=disabled" # protobuf/abseil headers need C++20; VLC builds as C++17
    # The medialibrary plugin is not packaged in nixpkgs, and the test suite
    # unconditionally depends on it.
    "-Dtests=disabled"
  ];

  installPhase = ''
    runHook preInstall

    meson install --no-rebuild

    # The meson install ships no desktop entry or icons, so generate them from
    # the source tree. VLC 4 dropped --started-from-file; passing it makes vlc
    # exit with "Unknown option".
    srcroot="$NIX_BUILD_TOP/$sourceRoot"
    mimetypes="$(sed 's/\s*#.*$//g' "$srcroot/share/vlc.desktop.mimetypes" | grep -v '^$' | tr '\n' ';')"
    mkdir -p $out/share/applications
    sed -e "s,@bindir@,$out/bin,g" -e "s,@MIMETYPES@,$mimetypes,g" \
      -e 's, --started-from-file,,' \
      "$srcroot/share/vlc.desktop.in" > $out/share/applications/vlc4.desktop
    for sz in 16x16 32x32 48x48 128x128 256x256; do
      if [ -f "$srcroot/share/icons/$sz/vlc.png" ]; then
        install -Dm444 "$srcroot/share/icons/$sz/vlc.png" \
          $out/share/icons/hicolor/$sz/apps/vlc4.png
      fi
    done

    runHook postInstall
  '';

  # VLC 4 does not load the D-Bus control interface by default, so without
  # this there is no MPRIS service and media keys / playerctl cannot see the
  # player.
  preFixup = ''
    qtWrapperArgs+=("''${gappsWrapperArgs[@]}")

    # The xcb plugins link libvlc_xcb_events.so from $out/lib/vlc, which is
    # not in their RUNPATH, so they fail to load without this.
    for f in $out/lib/vlc/plugins/video_output/libxcb_*_plugin.so; do
      if [ -f "$f" ]; then
        patchelf --add-rpath $out/lib/vlc "$f"
      fi
    done
  '';

  meta = {
    description = "VLC 4.0 development build with the Juxtopposed interface redesign";
    homepage = "https://github.com/dsojevic/juxtopposed-vlc";
    license = with lib.licenses; [ gpl2Plus cc-by-40 ];
    mainProgram = "vlc";
    platforms = lib.platforms.linux;
  };
});

  # VLC 4 does not load the D-Bus control interface by default, so without
  # this there is no MPRIS service: media keys (and playerctl, KDE Connect,
  # etc.) have nothing to talk to. This tree rejects the --control flag in
  # its command-line parser, so --extraintf is used instead. Wrapping outside
  # the compiled derivation keeps this a no-recompile change.
  wrapped = runCommand "vlc-wrapped" { nativeBuildInputs = [ makeWrapper ]; } ''
    makeWrapper ${vlc}/bin/vlc $out/bin/vlc --add-flags "--extraintf dbus"
  '';
in
symlinkJoin {
  inherit (vlc) pname version meta;
  name = "${vlc.pname}-${vlc.version}";
  paths = [ wrapped vlc ];
}
