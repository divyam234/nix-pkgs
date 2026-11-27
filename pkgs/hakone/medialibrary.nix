# SPDX-License-Identifier: GPL-2.0-or-later
# From Hakone's nix/medialibrary.nix; patches come from the pinned Hakone source.
{
  lib,
  stdenv,
  fetchurl,
  meson,
  ninja,
  pkg-config,
  sqlite,
  libjpeg,
  xxhash,
  patchDir,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "medialibrary";
  version = "0.14.1";

  src = fetchurl {
    url = "https://code.videolan.org/videolan/medialibrary/-/archive/${finalAttrs.version}/medialibrary-${finalAttrs.version}.tar.bz2";
    hash = "sha256-duW1OWyyEMYa3dA/BrSdWWGpaXOzqrYrGVrF6uJdmKY=";
  };

  patches = map (name: patchDir + "/${name}") [
    "0001-preserve-windows-unc-storage-paths.patch"
    "0002-exclude-associated-tracks-from-media-lookup.patch"
    "0003-wait-for-transient-sqlite-locks.patch"
    "0004-replace-external-track-assignments.patch"
    "0005-persist-discovered-track-selections.patch"
    "0006-wake-eligible-priority-writers.patch"
    "0007-atomic-addon-playlist-append.patch"
  ];

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];
  buildInputs = [
    sqlite
    libjpeg
    xxhash
  ];
  mesonBuildType = "release";
  mesonFlags = [
    (lib.mesonEnable "libvlc" false)
    (lib.mesonEnable "tests" false)
  ];
  strictDeps = true;

  meta = {
    description = "VideoLAN media library with Hakone patches";
    homepage = "https://code.videolan.org/videolan/medialibrary";
    license = lib.licenses.lgpl21Plus;
    platforms = lib.platforms.linux;
  };
})
