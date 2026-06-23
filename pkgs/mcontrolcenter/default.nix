{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  qt6,
  libglvnd,
  stdenv,
  hicolor-icon-theme,
}:

let
  version = "0.5.1";

  pname = "mcontrolcenter";

  src = fetchurl {
    url = "https://github.com/dmitry-s93/MControlCenter/releases/download/${version}/MControlCenter-${version}-bin.tar.gz";
    hash = "sha256-cEhJuQenflZAVoBUE/2h4Uat6RkUxQ+yb1CLeeJrQbA=";
  };

  runtimeLibs = lib.makeLibraryPath [
    qt6.qtbase
    libglvnd
    stdenv.cc.cc.lib
  ];
in
stdenvNoCC.mkDerivation {
  inherit pname version src;

  sourceRoot = "MControlCenter-${version}-bin";

  nativeBuildInputs = [
    autoPatchelfHook
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    libglvnd
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall

    # Main binary
    install -Dm755 app/mcontrolcenter $out/bin/mcontrolcenter

    # Helper binary (D-Bus system service)
    install -Dm755 app/mcontrolcenter-helper $out/libexec/mcontrolcenter-helper

    # Desktop file
    install -Dm644 app/mcontrolcenter.desktop $out/share/applications/mcontrolcenter.desktop

    # Icon
    install -Dm644 app/mcontrolcenter.svg $out/share/icons/hicolor/scalable/apps/mcontrolcenter.svg

    # D-Bus system policy
    install -Dm644 app/mcontrolcenter-helper.conf $out/share/dbus-1/system.d/mcontrolcenter-helper.conf

    # D-Bus service (patch to use Nix store path)
    sed "s|/usr/libexec/mcontrolcenter-helper|$out/libexec/mcontrolcenter-helper|g" \
      app/mcontrolcenter.helper.service > mcontrolcenter.helper.service
    install -Dm644 mcontrolcenter.helper.service $out/share/dbus-1/system-services/mcontrolcenter.helper.service

    # Kernel module config for ec_sys
    install -Dm644 /dev/null $out/lib/modules-load.d/mcontrolcenter.conf
    echo "ec_sys" > $out/lib/modules-load.d/mcontrolcenter.conf

    install -Dm644 /dev/null $out/lib/modprobe.d/mcontrolcenter.conf
    echo "options ec_sys write_support=1" > $out/lib/modprobe.d/mcontrolcenter.conf

    runHook postInstall
  '';

  postFixup = ''
    patchelf $out/bin/mcontrolcenter --add-rpath ${runtimeLibs}
    patchelf $out/libexec/mcontrolcenter-helper --add-rpath ${runtimeLibs}
  '';

  meta = {
    description = "An application that allows you to change the settings of MSI laptops";
    homepage = "https://github.com/dmitry-s93/MControlCenter";
    license = lib.licenses.gpl3Only;
    maintainers = [ ];
    mainProgram = "mcontrolcenter";
    platforms = [ "x86_64-linux" ];
  };
}
