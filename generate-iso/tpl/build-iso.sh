#!/bin/bash

set -e

mkdir -p /archiso
cp -r /usr/share/archiso/configs/releng/* /archiso

mkdir -p /aurpkgs/repo
chmod -R 777 /aurpkgs

cd /aurpkgs

{% for package in packages.iso.aur %}
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
rm /archiso/airootfs/root/install.txt

cd /archiso
echo "{{ packages.iso.packages | join("\n") }}" >> packages.x86_64

sed -i 's@curl -o ${work_dir}/${arch}/airootfs/etc/pacman.d/mirrorlist@#@' build.sh
sed -i 's/lynx -dump -nolist/#/' build.sh

./build.sh -v
