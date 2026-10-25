# FFmpeg 8.1.2 with the RVRA patch rPlayHub needs.
#
# The iPhone encoder changes resolution mid-stream ("RVRA"). Stock FFmpeg decodes
# it without a warning and produces a garbled picture from the first downshift
# under motion, so the client must link this tree rather than the system FFmpeg.
{ lib, stdenv, fetchurl, pkg-config, nasm, zlib, rplayhubSrc }:

stdenv.mkDerivation rec {
  pname = "ffmpeg-rvra";
  version = "8.1.2";

  src = fetchurl {
    url = "https://ffmpeg.org/releases/ffmpeg-${version}.tar.xz";
    hash = "sha256-RkvrXnvwwxHmi0WuLwTpzCr4iFGrtAgiMXQqdNl7Ukw=";
  };

  patches = [ "${rplayhubSrc}/patches/ffmpeg-rvra.patch" ];
  patchFlags = [ "-p1" ];

  enableParallelBuilding = true;

  nativeBuildInputs = [ pkg-config ] ++ lib.optional stdenv.hostPlatform.isx86_64 nasm;
  buildInputs = [ zlib ];

  # Matches scripts/build-ffmpeg-rvra.sh: a plain LGPL tree, no autodetect, no
  # network, zlib on for the PNG decoder the GUI uses for app icons.
  configureFlags = [
    "--disable-doc"
    "--disable-autodetect"
    "--disable-network"
    "--enable-zlib"
    "--disable-ffplay"
    "--disable-ffprobe"
    "--disable-shared"
    "--enable-static"
    "--enable-pic"
  ];

  # client-c/Makefile looks for headers and archives side by side under
  # $FFMPEG_DIR/<module>/, and adds -I$FFMPEG_DIR, so build that tree.
  postInstall = ''
    for module in libavcodec libavutil libswresample libswscale libavformat libavfilter; do
      [ -d $out/include/$module ] || continue
      mkdir -p $out/tree/$module
      cp -r $out/include/$module/. $out/tree/$module/
      for archive in $out/lib/$module.a; do
        [ -e "$archive" ] && ln -sf "$archive" $out/tree/$module/
      done
    done
  '';

  meta = {
    description = "FFmpeg 8.1.2 with RVRA reference resampling for rPlayHub";
    license = lib.licenses.lgpl21Plus;
    platforms = lib.platforms.linux;
  };
}
