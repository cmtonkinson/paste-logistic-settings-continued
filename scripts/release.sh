#!/usr/bin/env zsh

# Everything below uses repo-relative paths (info.json, changelog.txt, the release files).
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

# Derive the next version from the latest tag.
LATEST=$(git tag --list 'v*' --sort=-version:refname | head -1)
CURRENT="${LATEST#v}"
IFS='.' read -r MAJOR MINOR PATCH <<<"${CURRENT:-0.0.0}"
case "$BUMP" in
major) VERSION="$((MAJOR + 1)).0.0" ;;
minor) VERSION="${MAJOR}.$((MINOR + 1)).0" ;;
patch) VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
esac
echo "Releasing v$VERSION (previous: ${LATEST:-none}) ..."

# The release script cleans up after itself, so if the release directory exists, something went
# wrong and we don't want to further muck it up.
if [ -d $RELEASE_DIR ]; then
  echo "Release directory already exists. Exiting."
  exit 1
fi

# If there are uncommitted changes, we don't want to release.
if [[ $(git status --porcelain) ]]; then
  echo "There are uncommitted changes. Exiting."
  exit 2
fi

# If there are unpushed commits, we don't want to release.
if [[ $(git log origin/main..HEAD) ]]; then
  echo "There are unpushed commits. Exiting."
  exit 3
fi

# If there isn't an entry in changelog.txt for this version, we don't want to release.
if ! grep -q "Version: $VERSION" changelog.txt; then
  echo "There is no entry in changelog.txt for $VERSION. Exiting."
  exit 4
fi

# Bump info.json (sed rather than jq, to keep its formatting) and commit only if it changed.
sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/" info.json
if ! git diff --quiet info.json; then
  git commit -m "Release v$VERSION" info.json
fi

mkdir -p $OLD_VERSIONS

# Create the directory, add the necessary files, and zip it up.
mkdir "$RELEASE_DIR"
cp -r $RELEASE_FILES "$RELEASE_DIR/"
zip -r $NAME-$VERSION.zip $RELEASE_DIR
mv $NAME-$VERSION.zip $OLD_VERSIONS/

# Tag this in the repo.
git tag -a v$VERSION -m "Release version $VERSION"
git push origin main v$VERSION

# Clean up the release directory.
rm -rf $RELEASE_DIR
