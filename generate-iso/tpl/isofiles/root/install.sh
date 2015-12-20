#!/bin/bash -vx

set -e

echo "{{ parted.commands | join ("\n") }}" | parted {{ parted.disk }}

until cryptsetup -v --cipher aes-xts-plain64 --key-size 512 -y luksFormat {{ fs.system.disk }}
do sleep 1; done

until cryptsetup open --type luks {{ fs.system.disk }} lvm
do sleep 1; done

pvcreate /dev/mapper/lvm
vgcreate main /dev/mapper/lvm
lvcreate -l +100%FREE -n root main
mkfs.ext4 /dev/mapper/main-root

{% if fs.boot.format %}
	mkfs.fat -F32 {{ fs.boot.disk }}
{% endif %}

mount /dev/mapper/main-root /mnt

mkdir /mnt/boot
mount {{ fs.boot.disk }} /mnt/boot

pacstrap /mnt base base-devel sudo {{ packages.system.packages | join(" ") }}

genfstab -U -p /mnt > /mnt/etc/fstab

cp ~/chroot-install.sh /mnt/

arch-chroot /mnt /bin/bash -vx /chroot-install.sh

rm /mnt/chroot-install.sh
