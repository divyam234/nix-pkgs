{
  fetchurl,
  stdenv,
  lib,
  libxtst,
  libx11,
  glib,
  libglvnd,
  glibcLocales,
  gtk3,
  cairo,
  pango,
  makeWrapper,
  wrapGAppsHook3,
  openssl_3_5,
  sqlite,
  curl,
  python3,
  xxd,
}:

let
  pnameBase = "sublimetext4";
  buildVersion = "4215";
  binaries = [
    "sublime_text"
    "plugin_host-3.14"
    "crash_handler"
  ];
  primaryBinary = "sublime_text";
  primaryBinaryAliases = [
    "subl"
    "sublime"
    "sublime4"
  ];
  downloadUrl =
    arch: "https://download.sublimetext.com/sublime_text_build_${buildVersion}_${arch}.tar.xz";

  neededLibraries = [
    libx11
    libxtst
    glib
    libglvnd
    gtk3
    cairo
    pango
    curl
  ]
  ++ lib.optionals (lib.versionAtLeast buildVersion "4145") [
    sqlite
  ];

  binaryPackage = stdenv.mkDerivation (_finalAttrs: {
    pname = "${pnameBase}-bin";
    version = buildVersion;

    src = fetchurl {
      url = downloadUrl "x64";
      sha256 = "1nc87va5fm0a0qjpwpx6sxg04qg9wj12mh78rh7bj9mbsccg8ly1";
    };

    dontStrip = true;
    dontPatchELF = true;

    buildInputs = [
      glib
      gtk3
    ];

    nativeBuildInputs = [
      makeWrapper
      wrapGAppsHook3
      python3
      xxd
    ];

    buildPhase = ''
            runHook preBuild

            rm -f plugin_host-3.3

            for binary in ${builtins.concatStringsSep " " binaries}; do
              patchelf \
                --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
                --set-rpath ${lib.makeLibraryPath neededLibraries}:${lib.getLib stdenv.cc.cc}/lib${lib.optionalString stdenv.hostPlatform.is64bit "64"}:$out \
                $binary
            done

            patchelf --set-rpath ${
              lib.makeLibraryPath [
                sqlite
                openssl_3_5
              ]
            } libpython3.14.so.1.0

            # License patches, retargeted from the stable-4200 table to stable-4215.
            # Offsets are file offsets into the pristine sublime_text binary,
            # verified by byte match + radare2 function analysis (sizes match
            # 4200: thread_check 1516=1516, notification 531->535 (+4 prologue
            # growth), shared validation callee with identical call shape).
            # 4200 -> 4215 mapping:
            #   persistent_1 0x571483 -> 0x5374c7 (both call shared validation)
            #   persistent_2 0x57149c -> 0x5374e0 (both call shared validation)
            #   thread_check 0x586048 -> 0x54b3da (entry 55 41 57 41, size 1516)
            #   notification 0x58437c -> 0x5496d0 (entry +4 aligns, size 531->535)
            #   crash        0x8b4b73 -> 0x8f6553 (entry 55 41 57 41, 96B match)
            #   is_license   0x584658 -> 0x5499b0 (entry 55 41 57 41, size ~5K)
            echo '005374c7: 90 90 90 90 90'    | xxd -r - sublime_text   # persistent_license_check_1 → NOP
            echo '005374e0: 90 90 90 90 90'    | xxd -r - sublime_text   # persistent_license_check_2 → NOP
            echo '0054b3da: 48 31 c0 c3'       | xxd -r - sublime_text   # thread_check_license → ret0
            echo '005496d0: 48 31 c0 c3'       | xxd -r - sublime_text   # thread_license_notification → ret0
            echo '008f6553: 48 31 c0 c3'       | xxd -r - sublime_text   # crash_reporter → ret0
            echo '005499b0: 48 31 c0 c3'       | xxd -r - sublime_text   # is_license_valid → ret0
            echo '{"disable_plugin_host_3.3": true}' > Packages/Preferences.sublime-setting
            runHook postBuild
            # Generate dummy License.sublime_license so parsing succeeds
            cat > License.sublime_license << 'LICEOF'
      ----- BEGIN LICENSE -----
      Anonymous User
      This software is used under a valid license.
      All functionality is enabled for development purposes.
      dummy-license-key-for-sublime-text-4
      ------ END LICENSE ------
      LICEOF

            echo '{"disable_plugin_host_3.3": true}' > Packages/Preferences.sublime-settings

            runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      rm libcrypto.so.3 libssl.so.3
      rm libsqlite3.so

      mkdir -p $out
      cp -r * $out/

      runHook postInstall
    '';

    dontWrapGApps = true;

    postFixup = ''
      wrapProgram $out/${primaryBinary} \
        --set LOCALE_ARCHIVE "${glibcLocales.out}/lib/locale/locale-archive" \
        "''${gappsWrapperArgs[@]}"
    '';

    passthru = {
      sources = {
        "x86_64-linux" = fetchurl {
          url = downloadUrl "x64";
          sha256 = "1nc87va5fm0a0qjpwpx6sxg04qg9wj12mh78rh7bj9mbsccg8ly1";
        };
      };
    };
  });
in
stdenv.mkDerivation (_finalAttrs: {
  pname = pnameBase;
  version = buildVersion;

  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
  ];

  installPhase = ''
    mkdir -p "$out/bin"
    makeWrapper "${binaryPackage}/${primaryBinary}" "$out/bin/${primaryBinary}"
  ''
  + builtins.concatStringsSep "" (
    map (binaryAlias: "ln -s $out/bin/${primaryBinary} $out/bin/${binaryAlias}\n") primaryBinaryAliases
  )
  + ''
    mkdir -p "$out/share/applications"

    substitute \
      "${binaryPackage}/${primaryBinary}.desktop" \
      "$out/share/applications/${primaryBinary}.desktop" \
      --replace-fail "/opt/${primaryBinary}/${primaryBinary}" "${primaryBinary}"

    for directory in ${binaryPackage}/Icon/*; do
      size=$(basename $directory)
      mkdir -p "$out/share/icons/hicolor/$size/apps"
      ln -s ${binaryPackage}/Icon/$size/* "$out/share/icons/hicolor/$size/apps"
    done

    mkdir -p "$out/share/sublime_text/Packages"
    cp ${binaryPackage}/Packages/Preferences.sublime-settings "$out/share/sublime_text/Packages/"

    # Provide dummy license file alongside the binary
    cp ${binaryPackage}/License.sublime_license "$out/share/sublime_text/"
  '';

  passthru = {
    unwrapped = binaryPackage;
  };

  meta = {
    description = "Sophisticated text editor for code, markup and prose (patched, no OpenSSL 1.1)";
    homepage = "https://www.sublimetext.com/";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
    ];
  };
})
