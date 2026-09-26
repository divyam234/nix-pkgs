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
  # License patches live in patches.json, keyed by build version.
  # New versions: uv run pkgs/sublime/gen_patches.py update \
  #   --ref-version <prev> --new-version <next> --tarball <url> --write
  # then bump buildVersion below.
  patchData = builtins.fromJSON (builtins.readFile ./patches.json);
  patchEntry =
    patchData.versions.${buildVersion}
      or (throw "sublime: no patch entry for build ${buildVersion} in patches.json");
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
      sha256 = patchEntry.sha256;
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

            # License patches from patches.json. Each site is precondition-checked
            # against its pristine bytes first, so a re-released tarball with
            # shifted code fails loudly instead of mis-patching.
            ${lib.concatMapStrings (p: ''
              actual=$(xxd -p -s $((16#${p.offset})) -l ${toString p.length} sublime_text | tr -d '\n')
              if [ "$actual" != "${p.original}" ]; then echo "sublime patch precondition failed for ${p.name} at ${p.offset}: got $actual" >&2; exit 1; fi
            '') patchEntry.patches}
            ${lib.concatMapStrings (p: ''
              echo '${p.offset}: ${p.patched}' | xxd -r - sublime_text   # ${p.name}
            '') patchEntry.patches}
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
          sha256 = patchEntry.sha256;
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
