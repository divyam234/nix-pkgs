{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dbus,
  libdisplay-info,
  libglvnd,
  libinput,
  libxkbcommon,
  libgbm,
  pango,
  pipewire,
  seatd,
  systemd,
  wayland,
}:

let
  version = "26.04";

  sources = {
    x86_64-linux = {
      asset = "niri-v${version}-linux-amd64.tar.gz";
      hash = "sha256-u7rqBFvjFGJi6OFREBLExxBxzpmEuPj1g35dh9CRYOY=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "niri is not packaged for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "niri";
  inherit version;

  src = fetchurl {
    url = "https://github.com/divyam234/nix-pkgs/releases/download/niri-v${version}/${source.asset}";
    inherit (source) hash;
  };

  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    dbus
    libdisplay-info
    libglvnd
    libinput
    libxkbcommon
    libgbm
    pango
    pipewire
    seatd
    systemd
    wayland
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -r bin lib share "$out/"
    chmod +x "$out/bin/niri" "$out/bin/niri-session"
    patchShebangs "$out/bin/niri-session"
    substituteInPlace "$out/share/systemd/user/niri.service" \
      --replace-fail 'ExecStart=niri --session' "ExecStart=$out/bin/niri --session"

    runHook postInstall
  '';

  passthru.providedSessions = [ "niri" ];

  meta = {
    description = "Scrollable-tiling Wayland compositor";
    homepage = "https://github.com/niri-wm/niri";
    changelog = "https://github.com/niri-wm/niri/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
    mainProgram = "niri";
    platforms = builtins.attrNames sources;
  };
}
