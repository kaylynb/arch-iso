#!/bin/bash -vx

set -e

sed -i 's/#Color/Color/' /etc/pacman.conf

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

{% if keymap %}echo "KEYMAP={{ keymap }}" > /etc/vconsole.conf{% endif %}
{% if consolefont %}echo "FONT={{ consolefont }}" >> /etc/vconsole.conf{% endif %}

ln -sf /usr/share/zoneinfo/{{ localtime }} /etc/localtime
hwclock --systohc --utc

echo {{ hostname }} > /etc/hostname

echo "127.0.0.1	localhost.localdomain	localhost	{{ hostname }}
::1	localhost.localdomain	localhost	{{ hostname }}" > /etc/hosts

cat << EOF > /etc/mkinitcpio.conf
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base systemd autodetect modconf block keyboard sd-vconsole sd-encrypt sd-lvm2 filesystems fsck)
COMPRESSION=(lz4)
COMPRESSION_OPTIONS=()
EOF

mkinitcpio -p linux

mkdir -p /boot/loader/entries

cat << EOF > /boot/loader/entries/arch-{{ hostname }}.conf
title	Arch Linux
linux	/vmlinuz-linux
initrd	/intel-ucode.img
initrd	/initramfs-linux.img
options rw root=/dev/mapper/main-root rd.luks.name=$1=main rd.luks.options=discard
EOF

if [ ! -f /boot/loader/loader.conf ]; then
	echo "default arch-{{ hostname }}" > /boot/loader/loader.conf
fi

bootctl install

until passwd
do sleep 1; done

useradd -m -g users -G wheel -s /bin/bash kaylyn

until passwd kaylyn
do sleep 1; done

echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel
