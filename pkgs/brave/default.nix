{
  lib,
  stdenv,
  fetchurl,
  buildPackages,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  dpkg,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  adwaita-icon-theme,
  gsettings-desktop-schemas,
  gtk3,
  gtk4,
  qt6,
  libx11,
  libxscrnsaver,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxtst,
  libdrm,
  libkrb5,
  libuuid,
  libxkbcommon,
  libxshmfence,
  libgbm,
  nspr,
  nss,
  pango,
  pciutils,
  pipewire,
  snappy,
  speechd-minimal,
  udev,
  wayland,
  xdg-utils,
  coreutils,
  libxcb,
  vulkan-loader,
  zlib,
  commandLineArgs ? "",
  pulseSupport ? true,
  libpulseaudio,
  libGL,
  libvaSupport ? true,
  libva,
  enableVideoAcceleration ? libvaSupport,
  vulkanSupport ? false,
  enableVulkan ? vulkanSupport,
}:

let
  version = "1.99.57";

  sources = {
    x86_64-linux = {
      asset = "brave-browser_1.99.57_amd64.deb";
      hash = "sha256-jNFMV/f9bXnf2aJUUBdbVDihsRtWX/XQitmRtwLen9U=";
    };

    aarch64-linux = {
      asset = "brave-browser_1.99.57_arm64.deb";
      hash = "sha256-0F30+KjElAdSRoIMF4l6RpYU+HmTindVfwJf2nvmHbQ=";
    };
  };

  sys = stdenv.hostPlatform.system;

  deps = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    gtk4
    libdrm
    libx11
    libGL
    libxkbcommon
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxshmfence
    libxtst
    libuuid
    libgbm
    nspr
    nss
    pango
    pciutils
    pipewire
    udev
    wayland
    libxcb
    zlib
    snappy
    speechd-minimal
    libkrb5
    vulkan-loader
    qt6.qtbase
  ]
  ++ lib.optional pulseSupport libpulseaudio
  ++ lib.optional libvaSupport libva;

  rpath = lib.makeLibraryPath deps + ":" + lib.makeSearchPathOutput "lib" "lib64" deps;
  binpath = lib.makeBinPath deps;

  enableFeatures =
    lib.optionals enableVideoAcceleration [
      "AcceleratedVideoDecodeLinuxGL"
      "AcceleratedVideoEncoder"
    ]
    ++ lib.optional enableVulkan "Vulkan";

  disableFeatures = [
    "OutdatedBuildDetector"
  ] ++ lib.optional enableVideoAcceleration "UseChromeOSDirectVideoDecoder";
in
stdenv.mkDerivation {
  pname = "brave";
  inherit version;

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchurl {
    url = "https://github.com/brave/brave-browser/releases/download/v${version}/${sources.${sys}.asset}";
    hash = sources.${sys}.hash;
  };

  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true;
  doInstallCheck = true;

  nativeBuildInputs = [
    dpkg
    (buildPackages.wrapGAppsHook3.override { makeWrapper = buildPackages.makeShellWrapper; })
  ];

  buildInputs = [
    glib
    gsettings-desktop-schemas
    gtk3
    gtk4
    adwaita-icon-theme
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out $out/bin
    cp -R usr/share $out
    cp -R opt/ $out/opt

    export BINARYWRAPPER=$out/opt/brave.com/brave/brave-browser
    substituteInPlace $BINARYWRAPPER \
      --replace-fail /bin/bash ${stdenv.shell} \
      --replace-fail 'CHROME_WRAPPER' 'WRAPPER'
    ln -sf $BINARYWRAPPER $out/bin/brave

    for exe in $out/opt/brave.com/brave/{brave,chrome_crashpad_handler}; do
      patchelf \
        --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        --set-rpath "${rpath}" $exe
    done

    substituteInPlace $out/share/applications/{brave-browser,com.brave.Browser}.desktop \
      --replace-fail /usr/bin/brave-browser-stable $out/bin/brave
    substituteInPlace $out/share/gnome-control-center/default-apps/brave-browser.xml \
      --replace-fail /opt/brave.com $out/opt/brave.com
    substituteInPlace $out/opt/brave.com/brave/default-app-block \
      --replace-fail /opt/brave.com $out/opt/brave.com

    for icon in 16 24 32 48 64 128 256; do
      mkdir -p $out/share/icons/hicolor/''${icon}x''${icon}/apps
      ln -s $out/opt/brave.com/brave/product_logo_''${icon}.png \
        $out/share/icons/hicolor/''${icon}x''${icon}/apps/brave-browser.png
    done

    rm $out/opt/brave.com/brave/libvulkan.so.1
    ln -s ${lib.getLib vulkan-loader}/lib/libvulkan.so.1 $out/opt/brave.com/brave/libvulkan.so.1

    ln -sf ${xdg-utils}/bin/xdg-settings $out/opt/brave.com/brave/xdg-settings
    ln -sf ${xdg-utils}/bin/xdg-mime $out/opt/brave.com/brave/xdg-mime

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${rpath}
      --prefix PATH : ${binpath}
      --suffix PATH : ${lib.makeBinPath [ xdg-utils coreutils ]}
      --set CHROME_WRAPPER brave
      ${lib.optionalString (enableFeatures != [ ]) ''
        --add-flags "--enable-features=${lib.concatStringsSep "," enableFeatures}\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+,WaylandWindowDecorations --enable-wayland-ime=true}}"
      ''}
      --add-flags "--disable-features=${lib.concatStringsSep "," disableFeatures}"
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
      --add-flags ${lib.escapeShellArg commandLineArgs}
    )
  '';

  installCheckPhase = ''
    runHook preInstallCheck
    $out/opt/brave.com/brave/brave --version
    runHook postInstallCheck
  '';

  meta = {
    homepage = "https://brave.com/";
    description = "Privacy-oriented browser for Desktop and Laptop computers";
    changelog = "https://github.com/brave/brave-browser/blob/master/CHANGELOG_DESKTOP.md#${lib.replaceStrings [ "." ] [ "" ] version}";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    license = lib.licenses.mpl20;
    platforms = builtins.attrNames sources;
    mainProgram = "brave";
  };
}
