{
  stdenv,
  lib,
  fetchFromGitHub,
  meson,
  gettext,
  glib,
  gjs,
  ninja,
  gtk4,
  webkitgtk_6_0,
  gsettings-desktop-schemas,
  wrapGAppsHook4,
  desktop-file-utils,
  gobject-introspection,
  glib-networking,
  pkg-config,
  libadwaita,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "foliate";
  version = "3.3.0-unstable-2026-04-08";
  rev = "67b6676d3f936c5edea91d4d903385ef39dd25c0";

  src = fetchFromGitHub {
    owner = "johnfactotum";
    repo = "foliate";
    inherit (finalAttrs) rev;
    hash = "sha256-bDmLSWnSjyy+ZjzfHJzoE5yPi2HitFkaLZ3pYfGChwE=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    desktop-file-utils
    gobject-introspection
    meson
    ninja
    pkg-config
    wrapGAppsHook4
  ];

  buildInputs = [
    gettext
    gjs
    glib
    glib-networking
    gsettings-desktop-schemas
    gtk4
    libadwaita
    webkitgtk_6_0
  ];

  meta = {
    description = "Simple and modern GTK eBook reader";
    homepage = "https://johnfactotum.github.io/foliate";
    license = lib.licenses.gpl3Only;
    maintainers = [ ];
    mainProgram = "foliate";
    platforms = lib.platforms.linux;
  };
})
