#!/bin/bash -x

set -e

echo "{{ parted.commands | join ("\n") }}" | parted {{ parted.disk }}

until cryptsetup -v --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 2000 -y luksFormat {{ fs.system.disk }}
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
