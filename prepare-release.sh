#!/usr/bin/env bash
for cmd in sed git curl uv cargo; do
    hash $cmd 2>/dev/null || { echo >&2 "error: $cmd not found"; exit 1; }
done

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Parsing command line
VERSION=

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            help
            return 0
            ;;
        *)
            if [ -z "$VERSION" ]; then
                VERSION="$1"
            else
               echo "Unknown parameter \"$1\""
               help
               exit 1
            fi 
            shift
            ;;
    esac
done

if [ -z "$VERSION" ]; then
    echo "A version must be set"
    help
    exit 1
fi

REPO_URL=https://github.com/gonicus/gouda-matrix

TMPDIR=$(mktemp -d)
trap '{ rm -rf -- "$TMPDIR"; }' EXIT

echo "* Checking out..."
git clone --depth 1 --branch  "$VERSION" "$REPO_URL" "$TMPDIR"

# Copy files from repo
echo "* Copy files over..."
cp "$TMPDIR/packaging/flatpak/"* "$SCRIPT_DIR"

echo "* Updating Cargo sources..."
curl -o "$SCRIPT_DIR/flatpak-cargo-generator.py" https://raw.githubusercontent.com/flatpak/flatpak-builder-tools/refs/heads/master/cargo/flatpak-cargo-generator.py
uv run --with aiohttp flatpak-cargo-generator.py "$TMPDIR/Cargo.lock" --yaml -o "$SCRIPT_DIR/cargo-sources.yml"

echo "* Updating version in plugin.info..."
sed -i "s/^version=.*$/version=${VERSION:1}/" "$SCRIPT_DIR/plugin.info"

echo "* Updating version in Flatpak definition..."
yq -i ".modules[0].sources[0] = {\"type\": \"git\", \"url\": \"https://github.com/gonicus/gouda-matrix.git\", \"tag\": \"$VERSION\"}" "$SCRIPT_DIR/de.gonicus.gonnect.plugin.Matrix.yml"
