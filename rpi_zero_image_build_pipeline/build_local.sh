#!/usr/bin/env bash
set -euo pipefail

# Local builder for the Raspberry Pi Zero (armhf) Lite image with PM2
# Requires: Debian/Ubuntu or Raspberry Pi OS with git, curl, unzip

ROOT_DIR="$(pwd)"
if [ ! -d "sa-image" ]; then
  echo "Run this from the directory that contains the 'sa-image/' folder."
  exit 1
fi

if [ ! -d "rpi-image-gen" ]; then
  git clone https://github.com/raspberrypi/rpi-image-gen.git
fi

sudo apt-get update
sudo apt-get install -y git unzip curl coreutils quilt parted qemu-user-static debootstrap zerofree zip   dosfstools libarchive-tools libcap2-bin grep rsync xz-utils file bc gpg pigz xxd bmap-tools

cd rpi-image-gen
CONF=$(ls config/*armhf*lite* 2>/dev/null | head -n 1 || true)
if [ -z "$CONF" ]; then
  echo "Could not find an armhf Lite config automatically. Check rpi-image-gen/config."
  exit 1
fi
echo "Using config: $CONF"
./build.sh -c "$CONF" ../sa-image

echo
echo "Build complete. Searching for generated .img files..."
find . -type f -name "*.img" -print
