#!/bin/bash -vx

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

{% if sshd %}
echo "sed -i 's/#\(PermitEmptyPasswords \).\+/\1yes/' /etc/ssh/sshd_config" >> airootfs/root/customize_airootfs.sh
echo 'systemctl enable sshd' >> airootfs/root/customize_airootfs.sh
sed -i '/INCLUDE/d' syslinux/archiso_sys.cfg
sed -i '1iDEFAULT select\nPROMPT 0\nTIMEOUT 50\nDEFAULT arch64' syslinux/archiso_sys.cfg
{% endif %}

echo 'systemctl enable systemd-networkd' >> airootfs/root/customize_airootfs.sh
echo 'systemctl enable systemd-resolved' >> airootfs/root/customize_airootfs.sh

./build.sh -v -N archlinux-{{ hostname }}
