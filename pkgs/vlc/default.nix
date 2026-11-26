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
  lua5_4,
  wayland-scanner,
  spirv-tools,
  qt6,
  kdePackages,
  patchelf,
  makeWrapper,
  runCommand,
  alsa-lib,
  avahi,
  cairo,
  dav1d,
  dbus,
  faad2,
  ffmpeg,
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
  libsecret,
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
  mpg123,
  ncurses,
  pipewire,
  samba,
  speex,
  srt,
  systemdLibs,
  taglib,
  vulkan-headers,
  vulkan-loader,
  wayland,
  wayland-protocols,
  zlib,
}:

let
  vlc = stdenv.mkDerivation (finalAttrs: {
    pname = "hakone-unwrapped";
    version = "1.0.0-beta.1";
    rev = "03fef03b761d38bf4a78b381ad937cdc2856d97d";

    src = fetchurl {
      url = "https://github.com/hakone-org/hakone/archive/${finalAttrs.rev}.tar.gz";
      hash = "sha256-h0+O/sNcEqLZOr6wzIm6u0oUuhM3QE9+bV40T9S0a/k=";
    };

    sourceRoot = "hakone-${finalAttrs.rev}";

    nativeBuildInputs = [
      meson
      ninja
      pkg-config
      python3
      flex
      bison
      gettext
      lua5_4
      wayland-scanner
      # Let qsb find spirv-opt so the Qt shaders get optimized.
      spirv-tools
      qt6.wrapQtAppsHook
      qt6.qttools
      patchelf
    ];

    buildInputs = [
      alsa-lib
      avahi
      cairo
      dav1d
      dbus
      faad2
      ffmpeg
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
      libsecret
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
      lua5_4
      mpg123
      ncurses
      pipewire
      samba
      speex
      srt
      systemdLibs
      taglib
      vulkan-headers
      vulkan-loader
      wayland
      wayland-protocols
      zlib
      qt6.qtbase
      qt6.qtdeclarative
      qt6.qtimageformats
      qt6.qtsvg
      qt6.qtwayland
      qt6.qtshadertools
      kdePackages.kwindowsystem
    ];

    strictDeps = true;

    postPatch = ''
      patchShebangs buildsystem modules/gui/qt/scripts extras/package/release
      substituteInPlace modules/text_renderer/freetype/platform_fonts.h \
        --replace-fail \
          /usr/share/fonts/truetype/freefont \
          ${freefont_ttf}/share/fonts/truetype
    '';

    # nixpkgs defaults to auto_features=enabled, which makes optional probes
    # (AArch64 branch protection, every optional codec) hard errors.
    mesonAutoFeatures = "auto";
    mesonBuildType = "release";

    mesonFlags = [
      "-Dqt=enabled"
      # Player-only build: no Rust/WASM add-on worker or library indexing.
      "-Daddon-runtime=disabled"
      "-Daddon_manager=false"
      "-Dmedialibrary=disabled"
      "-Drust=disabled"
      "-Dlua=enabled"
      "-Dnls=enabled"
      "-Dxcb=enabled"
      "-Dwayland=enabled"
      "-Ddbus=enabled"
      "-Dupdate-check=disabled"
      "-Dskins2=disabled"
      "-Dzvbi=disabled"
      "-Dchromecast=disabled" # protobuf/abseil headers need C++20; VLC builds as C++17
      "-Dtests=disabled"
    ];

    installPhase = ''
      runHook preInstall

      meson install --no-rebuild

      # Use Hakone's current templates, keeping the existing public desktop ID.
      srcroot="$NIX_BUILD_TOP/$sourceRoot"
      mimetypes="$(sed 's/\s*#.*$//g' "$srcroot/share/hakone.desktop.mimetypes" | grep -v '^$' | tr '\n' ';')"
      mkdir -p $out/share/applications
      sed -e "s,@bindir@,$out/bin,g" -e "s,@MIMETYPES@,$mimetypes,g" \
        -e 's, --started-from-file,,' \
        "$srcroot/share/hakone.desktop.in" > $out/share/applications/vlc4.desktop
      for sz in 16x16 32x32 48x48 128x128 256x256; do
        if [ -f "$srcroot/share/icons/$sz/hakone.png" ]; then
          install -Dm444 "$srcroot/share/icons/$sz/hakone.png" \
            $out/share/icons/hicolor/$sz/apps/vlc4.png
        fi
      done
      install -Dm444 "$srcroot/share/icons/hakone.svg" \
        $out/share/icons/hicolor/scalable/apps/vlc4.svg

      runHook postInstall
    '';

    postFixup = ''
      # The xcb plugins link libvlc_xcb_events.so from $out/lib/vlc, which is
      # not in their RUNPATH, so they fail to load without this.
      for f in $out/lib/vlc/plugins/video_output/libxcb_*_plugin.so; do
        if [ -f "$f" ]; then
          patchelf --add-rpath $out/lib/vlc "$f"
        fi
      done

      # Generate the cache after patching, with the timestamps Nix stores.
      find $out/lib/vlc/plugins -type f -exec touch -d @1 '{}' +
      $out/libexec/vlc/vlc-cache-gen $out/lib/vlc/plugins
      test -s $out/lib/vlc/plugins/plugins.dat
    '';

    meta = {
      description = "Hakone player-only build, without add-ons or media-library indexing";
      homepage = "https://github.com/hakone-org/hakone";
      license = with lib.licenses; [
        gpl2Plus
        lgpl21Plus
      ];
      mainProgram = "hakone";
      platforms = lib.platforms.linux;
    };
  });

  # Keep libraries, plugins and data private so stable VLC can share a profile.
  # The public wrapper also enables MPRIS, which VLC 4 does not load by default.
in
runCommand "vlc4-${vlc.version}"
  {
    pname = "vlc4";
    inherit (vlc) version;
    meta = vlc.meta // {
      mainProgram = "vlc4";
    };
    nativeBuildInputs = [ makeWrapper ];
    passthru.unwrapped = vlc;
  }
  ''
    makeWrapper ${vlc}/bin/hakone $out/bin/vlc4 --add-flags "--extraintf dbus"

    mkdir -p $out/share/applications
    substitute ${vlc}/share/applications/vlc4.desktop $out/share/applications/vlc4.desktop \
      --replace-fail '${vlc}/bin/hakone' "$out/bin/vlc4" \
      --replace-fail 'Icon=hakone' 'Icon=vlc4'
    sed -i '/^Name\(\[[^]]*\]\)\?=/s/=.*/=VLC/' $out/share/applications/vlc4.desktop
    ln -s ${vlc}/share/icons $out/share/icons
  ''
