#!/usr/bin/env zsh

NAME="paste-logistic-settings-continued"
RELEASE_DIR=$NAME
RELEASE_FILES=(info.json data.lua control.lua locale thumbnail.png CHANGELOG.txt LICENSE.txt)
VERSION=$(jq -r '.version' info.json)

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

# Create the directory, add the necessary files, and zip it up.
mkdir "$RELEASE_DIR"
cp $RELEASE_FILES "$RELEASE_DIR/"
zip -r $NAME-$VERSION.zip $RELEASE_DIR

# Tag this in the repo.
git tag -a v$VERSION -m "Release version $(<VERSION.txt)"
git push origin v$VERSION

# Clean up the release directory.
rm -rf $RELEASE_DIR

