#!/usr/bin/env zsh
set -euo pipefail

# Paths below are repo-relative.
SCRIPT="$(basename "$0")"
cd "$(dirname "$0")/.."

NAME="paste-logistic-settings-continued"
RELEASE_DIR=$NAME
RELEASE_FILES=(
  LICENSE.txt
  changelog.txt
  control.lua
  data.lua
  info.json
  locale
  settings.lua
  src
  thumbnail.png
)
OLD_VERSIONS="old-releases"

case "${1:-}" in
--major | --minor | --patch) BUMP="${1#--}" ;;
*)
  echo "Usage: $SCRIPT --major|--minor|--patch" >&2
  exit 1
  ;;
esac

LATEST=$(git tag --list 'v*' --sort=-version:refname | head -1)
CURRENT="${LATEST#v}"
IFS='.' read -r MAJOR MINOR PATCH <<<"${CURRENT:-0.0.0}"
case "$BUMP" in
major) VERSION="$((MAJOR + 1)).0.0" ;;
minor) VERSION="${MAJOR}.$((MINOR + 1)).0" ;;
patch) VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
esac
echo "Releasing v$VERSION (previous: ${LATEST:-none}) ..."

# A leftover release directory means an earlier run failed; do not build on it.
if [ -d $RELEASE_DIR ]; then
  echo "Release directory already exists. Exiting."
  exit 1
fi

if [[ $(git status --porcelain) ]]; then
  echo "There are uncommitted changes. Exiting."
  exit 2
fi

if [[ $(git log origin/main..HEAD) ]]; then
  echo "There are unpushed commits. Exiting."
  exit 3
fi

if ! grep -q "Version: $VERSION" changelog.txt; then
  echo "There is no entry in changelog.txt for $VERSION. Exiting."
  exit 4
fi

# sed, not jq: jq would reformat info.json.
sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/" info.json
if ! git diff --quiet info.json; then
  git commit -m "Release v$VERSION" info.json
fi

mkdir -p $OLD_VERSIONS

mkdir "$RELEASE_DIR"
cp -r $RELEASE_FILES "$RELEASE_DIR/"
zip -r $NAME-$VERSION.zip $RELEASE_DIR
mv $NAME-$VERSION.zip $OLD_VERSIONS/

git tag -a v$VERSION -m "Release version $VERSION"
git push origin main v$VERSION

rm -rf $RELEASE_DIR
