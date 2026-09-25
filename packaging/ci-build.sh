#!/bin/bash
# Build the Arch package from the checked-out tree into dist/.
# Runs as root inside an archlinux:base-devel container (CI or local docker).
set -euo pipefail

pacman -Syu --noconfirm --needed git python python-gobject namcap
git config --global --add safe.directory "$PWD"

# v0.1.1 -> 0.1.1; commits after a tag -> 0.1.1.r3.gabc1234
if tag=$(git describe --exact-match --tags --match 'v*' 2>/dev/null); then
  ver=${tag#v}
else
  ver=$(git describe --tags --long --match 'v*' | sed 's/^v//; s/-\([0-9]*\)-g/.r\1.g/')
fi
echo "building version $ver"

python -m py_compile plasma-webcam-brightness
python plasma-webcam-brightness --help >/dev/null

# runtime dependencies must exist in the official repos
depends=$(bash -c 'source packaging/aur/PKGBUILD; echo "${depends[@]}"')
pacman -Sp $depends >/dev/null

# same PKGBUILD as the AUR one, but fed this tree instead of the release tarball
build=$(mktemp -d)
git archive --prefix="plasma-webcam-brightness-$ver/" -o "$build/plasma-webcam-brightness-$ver.tar.gz" HEAD
sed -e "s/^pkgver=.*/pkgver=$ver/" \
    -e 's/^source=.*/source=("$pkgname-$pkgver.tar.gz")/' \
    -e "s/^sha256sums=.*/sha256sums=('SKIP')/" \
    packaging/aur/PKGBUILD > "$build/PKGBUILD"
id builder >/dev/null 2>&1 || useradd -m builder
chown -R builder "$build"
su builder -c "cd '$build' && makepkg --nodeps --noconfirm"

namcap "$build"/*.pkg.tar.zst || true
mkdir -p dist
cp "$build"/*.pkg.tar.zst dist/
ls -l dist
