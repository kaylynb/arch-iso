#!/bin/bash

set -e

mkdir -p /archiso
cp -r /usr/share/archiso/configs/releng/* /archiso

cp -r /isofiles/* /archiso/airootfs/

chmod +x /archiso/airootfs/root/install.sh
rm /archiso/airootfs/root/install.txt

cd /archiso
echo "{{ packages.iso.packages | join("\n") }}" >> packages.x86_64

sed -i 's@curl -o ${work_dir}/x86_64/airootfs/etc/pacman.d/mirrorlist@#@' build.sh
sed -i 's/lynx -dump -nolist/#/' build.sh

./build.sh -v -N archlinux-{{ hostname }}
