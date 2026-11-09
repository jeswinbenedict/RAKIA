#!/usr/bin/env sh
# SPDX-License-Identifier: Apache-2.0
#
# Prepares the two files the web build needs for its local SQLite store:
#   sqlite3.wasm     SQLite compiled to WebAssembly, downloaded from the
#                    official release of the `sqlite3` Dart package locked in
#                    pubspec.lock and checked against the SHA-256 pinned
#                    below;
#   drift_worker.js  the web worker hosting the database, compiled here from
#                    tool/web/drift_worker.dart with the locked packages, so
#                    its sqlite3 bindings always match the module.
# A pinned version that differs from pubspec.lock fails, so a dependency
# update cannot silently ship an unverified binary.
# Output: web/sqlite3/ (git-ignored). Requires the Dart SDK on PATH.
#
# Usage (from app/): sh tool/build_web_sqlite.sh
set -eu

SQLITE3_VERSION="3.9.0"
SQLITE3_WASM_SHA256="e7451780e78c56ff864fe9317a0fbcd6aeb2e8de3beba7f5efd963202f7ec3d9"

here=$(cd "$(dirname "$0")" && pwd)
app="$here/.."
out="$app/web/sqlite3"

locked() {
  # Version of package $1 in pubspec.lock.
  awk -v pkg="  $1:" '
    $0 == pkg { found = 1; next }
    found && /^  [^ ]/ { exit }
    found && $1 == "version:" { gsub(/"/, "", $2); print $2; exit }
  ' "$app/pubspec.lock"
}

actual=$(locked sqlite3)
if [ "$actual" != "$SQLITE3_VERSION" ]; then
  echo "pubspec.lock has sqlite3 $actual, but this script pins $SQLITE3_VERSION." >&2
  echo "Update the version and SHA-256 in tool/build_web_sqlite.sh." >&2
  exit 1
fi

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

fetch() {
  url=$1 dest=$2 expected=$3
  # A file already there (for example restored from CI's cache) is reused
  # only if it has the pinned hash.
  if [ -f "$dest" ] && [ "$(sha256 "$dest")" = "$expected" ]; then
    echo "OK  $(basename "$dest")  $expected  (already present)"
    return
  fi
  tmp="$dest.download"
  curl --fail --silent --show-error --location --proto '=https' \
    --retry 3 --output "$tmp" "$url"
  actual=$(sha256 "$tmp")
  if [ "$actual" != "$expected" ]; then
    rm -f "$tmp"
    echo "SHA-256 mismatch for $url" >&2
    echo "  expected $expected" >&2
    echo "  actual   $actual" >&2
    exit 1
  fi
  mv "$tmp" "$dest"
  echo "OK  $(basename "$dest")  $actual"
}

mkdir -p "$out"
fetch "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$SQLITE3_VERSION/sqlite3.wasm" \
  "$out/sqlite3.wasm" "$SQLITE3_WASM_SHA256"

cd "$app"
dart compile js -O4 --no-source-maps \
  -o "$out/drift_worker.js" tool/web/drift_worker.dart >/dev/null
rm -f "$out/drift_worker.js.deps"
echo "OK  drift_worker.js  compiled from tool/web/drift_worker.dart"
