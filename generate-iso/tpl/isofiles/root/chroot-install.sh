#!/bin/bash -vx

set -e

dirmngr < /dev/null

{% for package in packages.system.aur %}
echo 'Building {{package}}'
mkdir build
cd build
git clone {{ package }} .
chmod -R 777 .
sudo -u nobody makepkg
pacman --noconfirm -U `ls *pkg.tar.xz`
cd ../
rm -rf build
{% endfor %}

sed -i -e $'/\tissue_discards = 0/ s/= 0/= 1/' /etc/lvm/lvm.conf

sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
export LANG=en_US.UTF-8

touch /etc/vconsole.conf
{% if keymap %}echo "KEYMAP={{ keymap }}" >> /etc/vconsole.conf{% endif %}
{% if consolefont %}echo "FONT={{ consolefont }}" >> /etc/vconsole.conf{% endif %}

ln -sf /usr/share/zoneinfo/{{ localtime }} /etc/localtime
hwclock --systohc --utc

echo {{ hostname }} > /etc/hostname

echo "127.0.0.1	{{ hostname }}
::1	{{ hostname }}" > /etc/hosts

cat << EOF > /etc/mkinitcpio.conf
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base systemd autodetect modconf block keyboard sd-vconsole {% if fs.system.encrypted %} sd-encrypt {% endif %} lvm2 filesystems fsck)
COMPRESSION=(zstd)
COMPRESSION_OPTIONS=()
EOF

mkinitcpio -p linux

mkdir -p /boot/loader/entries

cat << EOF > /boot/loader/entries/arch-{{ hostname }}.conf
title	Arch Linux
linux	/vmlinuz-linux
initrd	/intel-ucode.img
initrd	/initramfs-linux.img
{% if fs.system.encrypted %}
options rw root=/dev/mapper/main-root rd.luks.name=$1=main rd.luks.options=discard
{% else %}
options rw root=/dev/mapper/main-root
{% endif %}
EOF

if [ ! -f /boot/loader/loader.conf ]; then
	echo "default arch-{{ hostname }}" > /boot/loader/loader.conf
fi

bootctl install

{% if network_wired %}
cat << EOF > /etc/systemd/network/20-wired.network
[Match]
Name={{ network_wired }}

[Network]
DHCP=ipv4

[DHCP]
RouteMetric=10
UseDomains=yes
EOF
{% endif %}

until passwd
do sleep 1; done

useradd -m -G wheel -s /bin/bash kaylyn

until passwd kaylyn
do sleep 1; done

echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel
