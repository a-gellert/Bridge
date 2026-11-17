#!/bin/sh
# Release web bundle for Poki: bundle/release/<title>/ and poki.zip (index.html at the zip root).
#   sh tools/build_poki.sh            # release
#   sh tools/build_poki.sh debug      # debug bundle in bundle/debug (no zip), for tools/web_smoke.js
set -e
VARIANT=${1:-release}
DEFOLD=${DEFOLD:-"D:/Programs/Defold"}
[ -d "$DEFOLD" ] || DEFOLD="C:/Program Files (x86)/Defold"
[ -d "$DEFOLD" ] || DEFOLD="C:/Defold"
JAVA=$(ls -d "$DEFOLD"/packages/jdk-*/bin/java.exe | tail -1)
JAR=$(ls "$DEFOLD"/packages/defold-*.jar | head -1)
OUT=bundle/$VARIANT
rm -rf "$OUT"
"$JAVA" -cp "$JAR" com.dynamo.bob.Bob --root . --platform wasm-web --architectures wasm-web \
  --variant "$VARIANT" --archive --bundle-output "$OUT" resolve build bundle
DIR=$(ls -d "$OUT"/*/ | head -1)
echo "bundle: $DIR"
[ "$VARIANT" = "release" ] || exit 0
rm -f poki.zip
# Windows bsdtar writes zip entries with forward slashes; PowerShell 5.1 Compress-Archive writes
# "archive\game0.arcd", which Linux-hosted portals unpack as a flat file name and the game fails to load.
TAR=/c/Windows/System32/tar.exe
[ -x "$TAR" ] || TAR=tar
(cd "$DIR" && "$TAR" -a -c -f ../../../poki.zip index.html dmloader.js *.wasm *_wasm.js archive)
ls -la poki.zip
