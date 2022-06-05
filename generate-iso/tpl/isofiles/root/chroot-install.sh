#!/bin/bash -vx

set -e

dirmngr < /dev/null

{% for package in packages.system.aur %}
echo 'Building {{package}}'
mkdir build
cd build
git clone https://aur.archlinux.org/{{ package }}.git .
chmod -R 777 .
sudo -u nobody makepkg -rs	
pacman --noconfirm -U `ls *pkg.tar.xz`
cd ../
rm -rf build
{% endfor %}

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

sed -i "s/HOOKS=.*/HOOKS=(base systemd autodetect modconf block keyboard sd-vconsole sd-encrypt btrfs filesystems)/g" /etc/mkinitcpio.conf

mkinitcpio -P

mkdir -p /boot/loader/entries

bootctl install

cat << EOF > /boot/loader/loader.conf
default arch.conf
EOF

LUKS_UUID=`cryptsetup luksUUID $1`
KERNEL_TYPE="$2"
ROOT_UUID="$3"

cat << EOF > /boot/loader/entries/arch.conf
title	Arch Linux
linux	/vmlinuz-$KERNEL_TYPE
initrd	/intel-ucode.img
initrd	/initramfs-$KERNEL_TYPE.img
options rw root=/dev/mapper/root rd.luks.name=$LUKS_UUID=root
EOF

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

systemctl enable systemd-networkd
{% endif %}

systemctl enable systemd-resolved

until passwd
do sleep 1; done

# Setup snapper
umount /.snapshots
rm -r /.snapshots
snapper --no-dbus -c root create-config /
btrfs subvolume delete /.snapshots
mkdir /.snapshots
chmod 750 /.snapshots
mount UUID="$ROOT_UUID" -o subvol=@/.snapshots /.snapshots

# Setup user and snapper
btrfs subvolume create /home/kaylyn
btrfs subvolume create /home/kaylyn/.cache
chattr +C /home/kaylyn/.cache

{% if user_snapshots %}
snapper --no-dbus -c home_kaylyn create-config /home/kaylyn
mkdir -p /home/kaylyn/.snapshots
mkdir -p /home/kaylyn/.cache
mount UUID="$ROOT_UUID" -o subvol=@/home/kaylyn/.snapshots /home/kaylyn/.snapshots
mount UUID="$ROOT_UUID" -o subvol=@/home/kaylyn/.cache /home/kaylyn/.cache

snapper --no-dbus -c home_kaylyn create --read-write --description "Filesytem Creation"
mount UUID="$ROOT_UUID" -o subvol=@/home/kaylyn/.snapshots/1/snapshot /home/kaylyn
{% else %}
mount UUID="$ROOT_UUID" -o subvol=@/home/kaylyn /home/kaylyn
mount UUID="$ROOT_UUID" -o subvol=@/home/kaylyn/.cache /home/kaylyn/.cache
{% endif %}

useradd -M -G wheel -s /bin/bash kaylyn
chown kaylyn: /home/kaylyn
chown kaylyn: /home/kaylyn/.cache

until passwd kaylyn
do sleep 1; done

echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel
