{
  lib,
  stdenvNoCC,
  fetchurl,
  gpuiApp,
  gst_all_1,
  alsa-lib,
  alsa-plugins,
  dbus,
  fontconfig,
  freetype,
  glib-networking,
  libx11,
  libxcursor,
  libxi,
  pipewire,
  sqlite,
  symlinkJoin,
  webkitgtk_4_1,
}:

let
  version = "0.48.1";

  sources = {
    x86_64-linux = {
      asset = "sonora-v${version}-x86_64-unknown-linux-gnu";
      hash = "sha256-NtES2hlXk5piA+vwnmg3LXiIO9y5wlFkdrMHHQCqFU4=";
    };
  };

  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "sonora is not packaged for ${stdenvNoCC.hostPlatform.system}");

  # WebKit plays a page's media through GStreamer and aborts its web process
  # when no audio sink element exists. The webkitgtk closure carries only
  # core and base, while autoaudiosink lives in good.
  gstPluginPath = lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" (
    with gst_all_1;
    [
      gstreamer
      gst-plugins-base
      gst-plugins-good
    ]
  );

  alsaPluginDirectory = symlinkJoin {
    name = "sonora-alsa-plugins";
    paths = [
      "${pipewire}/lib/alsa-lib"
      "${alsa-plugins}/lib/alsa-lib"
    ];
  };
in
gpuiApp {
  pname = "sonora";
  inherit version;

  src = fetchurl {
    url = "https://github.com/sonorahq/sonora/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  binaryPath = "bin/sonora";

  buildInputs = [
    alsa-lib
    dbus
    fontconfig
    freetype
    glib-networking
    libx11
    libxcursor
    libxi
    sqlite
    webkitgtk_4_1
  ];

  extraWrapperArgs = [
    "--set"
    "ALSA_PLUGIN_DIR"
    "${alsaPluginDirectory}/lib/alsa-lib"
    "--prefix"
    "GIO_EXTRA_MODULES"
    ":"
    "${glib-networking}/lib/gio/modules"
    "--prefix"
    "GST_PLUGIN_SYSTEM_PATH_1_0"
    ":"
    gstPluginPath
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/sonora"
    install -Dm644 ${./sonora.desktop} "$out/share/applications/sonora.desktop"
    substituteInPlace "$out/share/applications/sonora.desktop" \
      --replace-fail 'Exec=sonora' "Exec=$out/bin/sonora"
    install -Dm644 ${./sonora.svg} \
      "$out/share/icons/hicolor/scalable/apps/sonora.svg"

    runHook postInstall
  '';

  meta = {
    description = "Native, familiar music streaming client";
    homepage = "https://github.com/sonorahq/sonora";
    license = with lib.licenses; [
      gpl3Plus
      ofl
      isc
    ];
    mainProgram = "sonora";
    platforms = builtins.attrNames sources;
  };
}
