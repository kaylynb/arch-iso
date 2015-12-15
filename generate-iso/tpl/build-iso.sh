#!/bin/bash

set -e

mkdir -p /archiso
cp -r /usr/share/archiso/configs/releng/* /archiso

mkdir -p /aurpkgs/repo
chmod -R 777 /aurpkgs

cd /aurpkgs


{% for package in packages.aur %}
echo 'Building {{package}}'
mkdir build
cd build
curl -L {{ package }} | tar --strip-components=1 -xz
chmod -R 777 .
sudo -u nobody makepkg PKGDEST=../repo
cd ../
rm -rf build
{% endfor %}

chown -R root:root /aurpkgs

echo 'Adding Repo to Pacman conf'
repo-add /aurpkgs/repo/aurpkgs.db.tar.gz /aurpkgs/repo/*.pkg.tar.xz

echo "[aurpkgs]
SigLevel = Optional TrustAll
Server = file:///aurpkgs/repo" >> /archiso/pacman.conf

cp -r /isofiles/* /archiso/airootfs/

chmod +x /archiso/airootfs/root/install.sh

cd /archiso
echo "{{ packages.iso | join("\n") }}" >> packages.x86_64

./build.sh -v
