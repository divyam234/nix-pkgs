{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  libglvnd,
  libdrm,
  wayland,
  stdenv,
}:

let
  version = "4.0.0-beta.5";
  sources = {
    x86_64-linux = {
      asset = "vlc-juxtopposed-4.0.0-beta.5-linux-x86_64.tar.gz";
      hash = "sha256-TbEA04m5g8DIxsQlkoIThWP544GJ8NwxD08rwfbTbgo=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system} or (throw "vlc is not packaged for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "vlc-juxtopposed";
  inherit version;

  src = fetchurl {
    url = "https://github.com/dsojevic/juxtopposed-vlc/releases/download/${version}/${source.asset}";
    inherit (source) hash;
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  buildInputs = [ libglvnd libdrm wayland stdenv.cc.cc.lib ];
  # OpenGL is also loaded dynamically by the bundled Qt and VLC plugins.
  runtimeDependencies = [ libglvnd ];
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Keep Qt's relative qt.conf paths and the upstream AppRun isolation intact.
    mkdir -p "$out/lib/vlc" "$out/bin" "$out/share"
    cp -a . "$out/lib/vlc/"
    patchShebangs "$out/lib/vlc/AppRun"
    makeWrapper "$out/lib/vlc/AppRun" "$out/bin/vlc"

    cp -a usr/share/applications usr/share/icons usr/share/pixmaps "$out/share/"
    substituteInPlace "$out/share/applications/vlc-juxtopposed.desktop" \
      --replace-fail 'Exec=vlc' "Exec=$out/bin/vlc %U"

    runHook postInstall
  '';

  meta = {
    description = "VLC media player with Juxtopposed's redesigned native interface";
    homepage = "https://github.com/dsojevic/juxtopposed-vlc";
    license = with lib.licenses; [ gpl2Plus lgpl21Plus cc-by-40 ofl ];
    mainProgram = "vlc";
    platforms = [ "x86_64-linux" ];
  };
}
