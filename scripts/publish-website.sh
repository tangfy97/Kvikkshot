#!/bin/zsh
# Copies the Kvikkshot pages into a checkout of the tang-spark.no site, ready to review and push
# (Netlify deploys the site from its main branch). The site hosts no installers: the download buttons
# go to https://github.com/tangfy97/Kvikkshot/releases/latest, and the site's netlify.toml sends the old
# /kvikkshot/download links there too.
#
#   scripts/release.sh                                   # first: build/release/Kvikkshot-<version>.dmg
#   gh release create v<version> ...                     # then publish it on GitHub (docs/WEBSITE.md)
#   scripts/publish-website.sh ~/Documents/tang-spark.no
#
# The pages print the disk image's size and SHA-256, so this checks that the local disk image is the one
# in the GitHub release. It writes kvikkshot*.html, kvikkshot.css, kvikkshot/ and img/kvikkshot-*.
# It never copies a disk image, edits netlify.toml, commits or pushes.
set -euo pipefail
cd "$(dirname "$0")/.."

site=${1:?usage: scripts/publish-website.sh <tang-spark.no checkout>}
[[ -f $site/netlify.toml && -f $site/styles.css ]] || { echo "error: $site is not the tang-spark.no site" >&2; exit 1; }
version=$(sed -nE 's/^ *MARKETING_VERSION: "?([^"]*)"?$/\1/p' project.yml)
dmg=build/release/Kvikkshot-$version.dmg

[[ -f $dmg ]] || { echo "error: $dmg not found; run scripts/release.sh first" >&2; exit 1; }
if ! xcrun stapler validate -q "$dmg" 2>/dev/null; then
  echo "error: $dmg is not notarized; publish only what scripts/release.sh built with notarization" >&2
  exit 1
fi
released=$(gh release view "v$version" --repo tangfy97/Kvikkshot --json assets \
  --jq ".assets[] | select(.name == \"Kvikkshot-$version.dmg\") | .digest" 2>/dev/null || true)
if [[ $released != "sha256:$(shasum -a 256 "$dmg" | cut -d' ' -f1)" ]]; then
  echo "error: $dmg is not the disk image in GitHub release v$version; publish that release first" >&2
  exit 1
fi

/usr/bin/python3 -I website/generate.py
cp website/dist/*.html "$site/"
cp website/static/kvikkshot.css "$site/"
mkdir -p "$site/kvikkshot"
cp website/static/kvikkshot/* "$site/kvikkshot/"
# The English page uses the site's shared img/ folder, like the other Plakat pages
cp website/static/kvikkshot/icon-256.png "$site/img/kvikkshot-icon.png"
cp website/static/kvikkshot/screenshot-en.jpg "$site/img/kvikkshot-shot.jpg"

echo "Copied the Kvikkshot $version pages into $site. Review with 'git -C $site status', then commit and push."
