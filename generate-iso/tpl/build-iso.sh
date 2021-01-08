#!/bin/bash -vx

set -e

mkdir -p /archiso
cp -r /usr/share/archiso/configs/releng/* /archiso

cp -r /isofiles/* /archiso/airootfs/

chmod +x /archiso/airootfs/root/install.sh

mkdir -p airootfs/etc/pacman.d
cp /etc/pacman.d/mirrorlist airootfs/etc/pacman.d/

cd /archiso
sed -i 's/broadcom-wl/#broadcom-wl/' packages.x86_64
echo "{{ packages.iso.packages | join("\n") }}" >> packages.x86_64

{% if sshd %}
sed -i 's/#\(PermitEmptyPasswords \).\+/\1yes/' airootfs/etc/ssh/sshd_config
mkdir -p airootfs/etc/systemd/system/multi-user.target.wants
ln -s /usr/lib/systemd/system/sshd.service airootfs/etc/systemd/system/multi-user.target.wants/
{% endif %}

echo 'systemctl enable systemd-networkd' >> airootfs/root/customize_airootfs.sh
echo 'systemctl enable systemd-resolved' >> airootfs/root/customize_airootfs.sh

mkarchiso -v /archiso
