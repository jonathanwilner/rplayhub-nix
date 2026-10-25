# rPlayHub 0.1.3 built from source: the cdhost engine (C) and the SDL2 + Dear
# ImGui client (C++), for x86_64-linux and aarch64-linux.
{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  symlinkJoin,
  pkg-config,
  makeWrapper,
  patchelf,
  SDL2,
  libX11,
  libXext,
  libGL,
  zlib,
  openssl,
  curl,
  libimobiledevice,
  libusbmuxd,
  libplist,
  libimobiledevice-glue,
  libtatsu,
  ffmpeg-rvra,
  rplayhubSrc,
}:

let
  version = "0.1.3";

  src = rplayhubSrc;

  # Pinned by scripts/fetch-gui-deps.sh.
  imgui = fetchFromGitHub {
    owner = "ocornut";
    repo = "imgui";
    rev = "v1.91.8";
    hash = "sha256-+BuSAXvLvOYOmENzxd1pGDE6llWhTGVu7C3RnoVLVzg=";
  };
  jsonHpp = fetchurl {
    url = "https://github.com/nlohmann/json/releases/download/v3.11.3/json.hpp";
    hash = "sha256-m+pMgGbvShwgayvlo2MC+JJvf9xgh69dILQX0M8QPqY=";
  };

  # CI clones the STABLE-2_2_1_RELEASE tag into deps/lwip.
  lwip = fetchFromGitHub {
    owner = "lwip-tcpip";
    repo = "lwip";
    rev = "STABLE-2_2_1_RELEASE";
    hash = "sha256-8TYbUgHNv9SV3l203WVfbwDEHFonDAQqdykiX9OoM34=";
  };

  # One prefix with include/ and lib/ from the modern libimobiledevice stack,
  # for the engine's IMD_PREFIX.
  imd = symlinkJoin {
    name = "rplayhub-imd-prefix";
    paths = map lib.getDev [
      libimobiledevice
      libusbmuxd
      libplist
      libimobiledevice-glue
      libtatsu
    ] ++ map lib.getLib [
      libimobiledevice
      libusbmuxd
      libplist
      libimobiledevice-glue
      libtatsu
    ];
  };

  runtimeLibs = [
    SDL2
    libX11
    libXext
    libGL
    zlib
    openssl
    curl
    libimobiledevice
    libusbmuxd
    libplist
    libimobiledevice-glue
    libtatsu
  ];
in
stdenv.mkDerivation {
  pname = "rplayhub";
  inherit version src;

  nativeBuildInputs = [ pkg-config makeWrapper patchelf ];
  buildInputs = runtimeLibs;

  # Reproduce the deps/ layout the Makefiles expect.
  postPatch = ''
    mkdir -p deps/json
    ln -s ${lwip} deps/lwip
    ln -s ${imgui} deps/imgui
    ln -s ${jsonHpp} deps/json/json.hpp
    ln -s ${ffmpeg-rvra}/tree deps/ffmpeg
  '';

  configurePhase = ":";

  buildPhase = ''
    runHook preBuild
    make -C host-c IMD_PREFIX=${imd} OPENSSL=${openssl.dev}
    make -C client-c rplay-gui \
      FFMPEG_DIR=$PWD/deps/ffmpeg \
      IMGUI_DIR=$PWD/deps/imgui
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 host-c/cdhost $out/libexec/rplayhub/cdhost
    install -Dm755 client-c/rplay-gui $out/bin/rplayhub

    cat > $out/bin/rplayhub-engine <<EOF
    #!/bin/sh
    # rPlayHub engine: binds the USB phone and serves 127.0.0.1:9876 (control)
    # and :9877 (video). Runs unprivileged on its own userspace TCP/IP stack.
    export RPLAY_USERSPACE_NET="\''${RPLAY_USERSPACE_NET:-1}"
    exec $out/libexec/rplayhub/cdhost "\$@"
    EOF
    chmod 755 $out/bin/rplayhub-engine

    if [ -f scripts/fetch-ddi.sh ]; then
      install -Dm755 scripts/fetch-ddi.sh $out/bin/rplayhub-fetch-ddi
    fi

    install -d $out/share/rplayhub/fonts
    install -m644 client-c/fonts/Inter-*.ttf $out/share/rplayhub/fonts/
    install -Dm644 client-c/packaging/rplayhub.desktop \
      $out/share/applications/rplayhub.desktop
    for size in 128 256; do
      icon=app/rPlayHub/Assets.xcassets/AppIcon.appiconset/icon''${size}x''${size}.png
      [ -f "$icon" ] && install -Dm644 "$icon" \
        $out/share/icons/hicolor/''${size}x''${size}/apps/rplayhub.png
    done

    rpath="${lib.makeLibraryPath runtimeLibs}"
    patchelf --set-rpath "$rpath" $out/bin/rplayhub
    patchelf --set-rpath "$rpath" $out/libexec/rplayhub/cdhost

    wrapProgram $out/bin/rplayhub --prefix PATH : ${lib.makeBinPath [ curl ]}
    runHook postInstall
  '';

  meta = {
    description = "rPlayHub: mirror and control an iPhone over CoreDevice";
    homepage = "https://github.com/rPlayAI/rPlayHub";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "rplayhub";
  };
}
