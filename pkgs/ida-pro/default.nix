{ pkgs, lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, copyDesktopItems
, perl, cairo, dbus, fontconfig, freetype, glib, gtk3, libdrm, libGL
, libkrb5, libsecret, libunwind, libxkbcommon, openssl
, qt6, libice, libsm, libX11, libxcb, libXext, libXi, libXrender
, zlib, curl, python313
}:

let
  version = "9.4";

  sources = {
    x86_64-linux = {
      asset = "ida-pro-${version}.tar.gz";
      hash = "sha256-Vx3R1qHCD4vBBNDPF5SEEe76G5PpcXiDqVKUITqTwGc=";
    };
  };

  source = sources.${stdenv.hostPlatform.system} or (throw "ida-pro is not packaged for ${stdenv.hostPlatform.system}");

  pythonForIDA = python313.withPackages (ps: with ps; [ rpyc ]);

  runtimeDependencies = [
    cairo dbus fontconfig freetype glib gtk3 libdrm libGL
    libkrb5 libsecret libunwind libxkbcommon openssl.out
    qt6.qtbase qt6.qtwayland
    stdenv.cc libice libsm libX11 libxcb libXext libXi libXrender
    zlib curl.out pythonForIDA
  ];
in
stdenv.mkDerivation {
  pname = "ida-pro";
  inherit version;

  src = fetchurl {
    url = "https://github.com/divyam234/nix-pkgs/releases/download/ida-pro-${version}/${source.asset}";
    hash = source.hash;
  };

  sourceRoot = "ida-pro-${version}";

  desktopItems = [
    (pkgs.makeDesktopItem {
      name = "ida-pro";
      exec = "ida";
      icon = "ida";
      comment = "Interactive disassembler";
      desktopName = "IDA Pro";
      genericName = "Interactive Disassembler";
      categories = [ "Development" ];
      startupWMClass = "IDA";
    })
  ];

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
    qt6.wrapQtAppsHook
    perl
  ];

  runtimeDependencies = runtimeDependencies;
  buildInputs = runtimeDependencies;

  dontConfigure = true;
  dontBuild = true;
  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    IDADIR="$out/opt/ida-pro-${version}"
    mkdir -p "$IDADIR" "$out/bin" "$out/lib"

    cp -r --no-preserve=mode x86_64-linux/* "$IDADIR"

    rm -f "$IDADIR"/Uninstall*.desktop

    install -Dm644 "$IDADIR/appico.png" "$out/share/pixmaps/ida.png"

    chmod +x "$IDADIR"/ida "$IDADIR"/idat 2>/dev/null || true

    if [ -d "kg_patch/x64linux" ]; then
      cp "kg_patch/x64linux/libida.so" "$IDADIR/"
      cp "kg_patch/x64linux/libida32.so" "$IDADIR/" 2>/dev/null || true
    fi

    if [ -f "kg_patch/idapro.hexlic" ]; then
      cp "kg_patch/idapro.hexlic" "$IDADIR/"
    fi

    for lib in "$IDADIR"/*.so "$IDADIR"/*.so.6; do
      [ -f "$lib" ] && ln -s "../opt/ida-pro-${version}/$(basename "$lib")" "$out/lib/$(basename "$lib")"
    done

    patchelf --add-needed libpython3.13.so "$out/lib/libida.so" 2>/dev/null || true
    patchelf --add-needed libcrypto.so "$out/lib/libida.so" 2>/dev/null || true
    patchelf --add-needed libsecret-1.so.0 "$out/lib/libida.so" 2>/dev/null || true

    addAutoPatchelfSearchPath "$IDADIR"

    for b in ida idat; do
      [ -x "$IDADIR/$b" ] || continue
      wrapProgram "$IDADIR/$b" \
        --prefix IDADIR : "$IDADIR" \
        --prefix QT_PLUGIN_PATH : "$IDADIR/plugins/platforms" \
        --prefix PYTHONPATH : "$out/bin/idalib/python" \
        --prefix PATH : "${pythonForIDA}/bin:$IDADIR" \
        --prefix LD_LIBRARY_PATH : "$out/lib"
      ln -s "$IDADIR/$b" "$out/bin/$b"
    done

    runHook postInstall
  '';

  meta = {
    description = "Interactive disassembler and debugger";
    homepage = "https://hex-rays.com/ida-pro/";
    maintainers = [ ];
    mainProgram = "ida";
    platforms = [ "x86_64-linux" ];
  };
}
