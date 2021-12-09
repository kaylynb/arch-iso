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
echo 'systemctl enable sshd' >> airootfs/root/customize_airootfs.sh
{% endif %}

echo 'systemctl enable systemd-networkd' >> airootfs/root/customize_airootfs.sh
echo 'systemctl enable systemd-resolved' >> airootfs/root/customize_airootfs.sh
echo 'systemctl disable reflector' >> airootfs/root/customize_airootfs.sh

sed -Ei 's/(iso_name=").*(")/\1archlinux-{{ hostname }}\2/' profiledef.sh

mkarchiso -v /archiso
