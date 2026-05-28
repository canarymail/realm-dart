#!/usr/bin/env bash
#
# Builds a static "hosted pub repository" for the `realm` package so it can be
# served from any static host (e.g. GitHub Pages). This lets you consume the
# patched realm SDK as a normal hosted dependency:
#
#   dependencies:
#     realm:
#       hosted: https://<org>.github.io/<repo>/
#       version: 20.2.0
#
# Why this exists: consuming realm as a git dependency drags in committed,
# dangling symlinks (e.g. ios/realm_dart.xcframework) that break `realm install`.
# The official publish pipeline strips those symlinks before packaging; this
# script reproduces that so the resulting package installs cleanly. The package
# keeps its real version (e.g. 20.2.0) so `realm install` can still download the
# matching native binaries from static.realm.io.
#
# Usage:
#   tool/build_pub_registry.sh <base-url> [output-dir]
#
#   <base-url>    Public URL the site will be served from, e.g.
#                 https://canarymail.github.io/realm-dart/
#   [output-dir]  Where to write the site (default: ./build/pub-registry)
#
set -euo pipefail

BASE_URL="${1:?Usage: build_pub_registry.sh <base-url> [output-dir]}"
OUT_DIR="${2:-build/pub-registry}"

# Normalise: ensure exactly one trailing slash.
BASE_URL="${BASE_URL%/}/"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="$REPO_ROOT/packages/realm"

VERSION="$(sed -ne 's/^version: \(.*\)/\1/p' "$PKG_DIR/pubspec.yaml" | tr -d '[:space:]')"
[ -n "$VERSION" ] || { echo "Could not read version from $PKG_DIR/pubspec.yaml" >&2; exit 1; }

STAGE="$OUT_DIR/.stage/realm"
SITE="$OUT_DIR/site"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/.stage" "$SITE/archives" "$SITE/api/packages"

echo "==> Staging realm@$VERSION (stripping native-binary symlinks, non-published content)"
# Copy preserving symlinks (cp -R does not dereference), then remove the committed native-binary
# symlinks (dangling in a fresh checkout) and dev-only/non-published content. This mirrors
# .github/workflows/publish-release.yml.
cp -R "$PKG_DIR" "$STAGE"
rm -f "$STAGE/android/src/main/cpp/lib" \
      "$STAGE/ios/realm_dart.xcframework" \
      "$STAGE/linux/binary" \
      "$STAGE/windows/binary" \
      "$STAGE/pubspec.lock"
rm -rf "$STAGE/tests" "$STAGE/.dart_tool"
find "$STAGE" -name 'pubspec_overrides.yaml' -delete
find "$STAGE" -name '.DS_Store' -delete
find "$STAGE" -name '*.realm*' -delete

# The remaining symlinks (CHANGELOG, LICENSE, analysis_options, ...) are relative and point at
# real repo files, but break once copied to a different depth. Replace each with the real file,
# resolving the target from the original package location.
while IFS= read -r link; do
  rel="${link#"$STAGE"/}"
  resolved="$(realpath "$PKG_DIR/$rel")" || { echo "ERROR: cannot resolve symlink $rel" >&2; exit 1; }
  [ -f "$resolved" ] || { echo "ERROR: symlink target is not a file: $rel -> $resolved" >&2; exit 1; }
  rm -f "$link"
  cp "$resolved" "$link"
done < <(find "$STAGE" -type l)

# Sanity check: nothing symlinked should remain.
if find "$STAGE" -type l | grep -q .; then
  echo "ERROR: symlinks still present after dereferencing:" >&2
  find "$STAGE" -type l >&2
  exit 1
fi

ARCHIVE="$SITE/archives/realm-$VERSION.tar.gz"
echo "==> Creating archive $ARCHIVE"
tar -C "$STAGE" -czf "$ARCHIVE" .
SHA="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"

echo "==> Writing index $SITE/api/packages/realm"
# Ruby ships with YAML + JSON on macOS, so we can faithfully convert the pubspec.
ARCHIVE_URL="${BASE_URL}archives/realm-$VERSION.tar.gz" \
SHA="$SHA" VERSION="$VERSION" PUBSPEC="$STAGE/pubspec.yaml" SITE_DIR="$SITE" \
ruby -ryaml -rjson -e '
  pubspec = YAML.load_file(ENV["PUBSPEC"])
  ver = {
    "version"        => ENV["VERSION"],
    "archive_url"    => ENV["ARCHIVE_URL"],
    "archive_sha256" => ENV["SHA"],
    "pubspec"        => pubspec,
  }
  index = { "name" => "realm", "latest" => ver, "versions" => [ver] }
  File.write(File.join(ENV["SITE_DIR"], "api", "packages", "realm"), JSON.pretty_generate(index))
'

touch "$SITE/.nojekyll"

echo
echo "Done. Static pub registry written to: $SITE"
echo "  package : realm@$VERSION"
echo "  sha256  : $SHA"
echo "  base url: $BASE_URL"
echo
echo "Consume with:"
echo "  realm:"
echo "    hosted: $BASE_URL"
echo "    version: $VERSION"
