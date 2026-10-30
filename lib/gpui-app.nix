{
  lib,
  stdenvNoCC,
  autoPatchelfHook,
  makeBinaryWrapper,
  glib,
  libdrm,
  libGL,
  libglvnd,
  libxcb,
  libxkbcommon,
  stdenv,
  vulkan-loader,
  wayland,
  xkeyboard_config,
}:

{
  binaryPath,
  extraWrapperArgs ? [ ],
  ...
}@args:

let
  runtimeLibraries = [
    glib
    libdrm
    libGL
    libglvnd
    libxcb
    libxkbcommon
    stdenv.cc.cc.lib
    vulkan-loader
    wayland
  ]
  ++ (args.buildInputs or [ ]);
  runtimePath = lib.makeLibraryPath runtimeLibraries;
in
stdenvNoCC.mkDerivation (
  (builtins.removeAttrs args [
    "binaryPath"
    "extraWrapperArgs"
  ])
  // {
    nativeBuildInputs = (args.nativeBuildInputs or [ ]) ++ [
      autoPatchelfHook
      makeBinaryWrapper
    ];
    buildInputs = runtimeLibraries;

    postFixup = ''
      patchelf "$out/${binaryPath}" --add-rpath ${runtimePath}
      wrapProgram "$out/${binaryPath}" \
        --prefix LD_LIBRARY_PATH : ${runtimePath} \
        --set-default XKB_CONFIG_ROOT "${xkeyboard_config}/share/X11/xkb" \
        ${lib.escapeShellArgs extraWrapperArgs}
    ''
    + (args.postFixup or "");
  }
)
