#!/bin/bash -vx

set -e

timedatectl set-ntp true

{% if parted %}
wipefs --all {{ parted.disk }}
echo "{{ parted.commands | join ("\n") }}" | parted {{ parted.disk }}
{% endif %}

{% if fs.system.encrypted %}
until cryptsetup -v --use-random --cipher aes-xts-plain64 --key-size 512 -y luksFormat {{ fs.system.disk }}
do sleep 1; done

until cryptsetup open --type luks {{ fs.system.disk }} lvm
do sleep 1; done

pvcreate /dev/mapper/lvm
vgcreate main /dev/mapper/lvm
{% else %}
pvcreate {{ fs.system.disk }}
vgcreate main {{ fs.system.disk }}
{% endif %}

lvcreate -L 12G -n free main
lvcreate -l +100%FREE -n root main
lvremove -f main/free
mkfs.ext4 /dev/mapper/main-root

{% if fs.boot.format %}
	mkfs.fat -F32 {{ fs.boot.disk }}
{% endif %}

mount /dev/mapper/main-root /mnt

mkdir /mnt/boot
mount {{ fs.boot.disk }} /mnt/boot

pacstrap /mnt base base-devel git sudo linux-headers intel-ucode {{ packages.system.packages | join(" ") }}

genfstab -U -p /mnt > /mnt/etc/fstab

cp ~/chroot-install.sh /mnt/

arch-chroot /mnt /bin/bash -vx /chroot-install.sh `lsblk -no UUID {{ fs.system.disk }} | head -1`

rm /mnt/chroot-install.sh
