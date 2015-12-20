#!/bin/bash -vx

set -e

{% for package in packages.system.aur %}
echo 'Building {{package}}'
mkdir build
cd build
curl -L {{ package }} | tar --strip-components=1 -xz
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

echo KEYMAP=colemak > /etc/vconsole.conf

ln -s /usr/share/zoneinfo/{{ localtime }} /etc/localtime
hwclock --systohc --utc

echo {{ hostname }} > /etc/hostname

echo "127.0.0.1	localhost.localdomain	localhost	{{ hostname }}
::1	localhost.localdomain	localhost	{{ hostname }}" > /etc/hosts

cat << EOF > /etc/mkinitcpio.conf
MODULES=""
BINARIES=""
FILES=""
HOOKS="{{ mkinitcpio.hooks | join(" ") }}"
COMPRESSION="lz4"
COMPRESSION_OPTIONS=""
EOF

mkinitcpio -p linux

mkdir -p /boot/loader/entries
cat << EOF > /boot/loader/entries/arch.conf
title	Arch Linux
linux	/vmlinuz-linux
initrd	/initramfs-linux.img
options	cryptdevice={{ fs.system.disk }}:main:allow-discards root=/dev/mapper/main-root rw
EOF

echo "default arch" > /boot/loader/loader.conf

bootctl install

passwd

useradd -m -g users -G wheel -s /bin/bash kaylyn
passwd kaylyn

echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel
