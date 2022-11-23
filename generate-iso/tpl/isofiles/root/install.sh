#!/bin/bash -vx

set -e

timedatectl set-ntp true

{% if parted %}
wipefs --all {{ parted.disk }}
echo "{{ parted.commands | join ("\n") }}" | parted {{ parted.disk }}
{% endif %}

sleep 2

DISK_BOOT="{{ fs.boot.disk }}"
DISK_SYSTEM="{{ fs.system.disk }}"
SYSTEM_HOSTNAME="{{ hostname }}"

{% if fs.boot.format %}
	mkfs.fat -F32 $DISK_BOOT
{% endif %}

# Setup crypt device
until cryptsetup -v -y luksFormat --sector-size=4096 "$DISK_SYSTEM"
do sleep 1; done

until cryptsetup open --persistent --allow-discards --type luks "$DISK_SYSTEM" root
do sleep 1; done

sleep 2

# Setup btrfs
mkfs.btrfs -L "$SYSTEM_HOSTNAME" /dev/mapper/root

sleep 2

ROOT_UUID=`lsblk -o UUID /dev/mapper/root | tail -1`
mount UUID="$ROOT_UUID" /mnt

btrfs subvolume create /mnt/@
for i in {opt,srv,swap,root,home}; do
	btrfs subvolume create /mnt/@/$i
done

mkdir -p /mnt/@/usr
btrfs subvolume create /mnt/@/usr/local

mkdir -p /mnt/@/var
for i in {abs,cache,log,spool,tmp}; do
	btrfs subvolume create /mnt/@/var/$i
	chattr +C /mnt/@/var/$i
done

# Setup snapshots
btrfs subvolume create /mnt/@/.snapshots
mkdir -p /mnt/@/.snapshots/1
btrfs subvolume create /mnt/@/.snapshots/1/snapshot

SNAPSHOT_DATE=`date +"%Y-%m-%d %H:%M:%S"`
cat << EOF > /mnt/@/.snapshots/1/info.xml
<?xml version="1.0"?>
<snapshot>
	<type>single</type>
	<num>1</num>
	<date>${SNAPSHOT_DATE}</date>
	<description>Root Filesytem Creation</description>
</snapshot>
EOF

SNAPSHOT_BTRFS_ID=`btrfs subvolume list /mnt | grep '@/.snapshots/1/snapshot' | awk '{print \$2}'`
btrfs subvolume set-default "$SNAPSHOT_BTRFS_ID" /mnt

# Remount snapshot
umount /mnt
mount UUID="$ROOT_UUID" -o compress=zstd,autodefrag,noatime /mnt

for i in {opt,srv,swap,root,home}; do
	mkdir -p /mnt/$i
	mount UUID="$ROOT_UUID" -o subvol=@/$i /mnt/$i
done

mkdir -p /mnt/usr/local
mount UUID="$ROOT_UUID" -o subvol=@/usr/local /mnt/usr/local

mkdir -p /mnt/var
for i in {abs,cache,log,spool,tmp}; do
	mkdir -p /mnt/var/$i
	mount UUID="$ROOT_UUID" -o subvol=@/var/$i /mnt/var/$i
done

mkdir -p /mnt/.snapshots
mount UUID="$ROOT_UUID" -o subvol=@/.snapshots /mnt/.snapshots

mkdir -p /mnt/boot
mount "$DISK_BOOT" /mnt/boot

{% if kernel %}
KERNEL_TYPE={{ kernel }}
{% else %}
KERNEL_TYPE=linux
{% endif %}

pacstrap /mnt base base-devel git sudo "$KERNEL_TYPE" "${KERNEL_TYPE}-headers" linux-firmware intel-ucode btrfs-progs efibootmgr snapper man-db man-pages texinfo neovim ansible {{ packages.system.packages | join(" ") }}

cp ~/chroot-install.sh /mnt/

arch-chroot /mnt /bin/bash -vx /chroot-install.sh $DISK_SYSTEM $KERNEL_TYPE $ROOT_UUID

genfstab -U /mnt > /mnt/etc/fstab
sed -i "s^,subvolid=$SNAPSHOT_BTRFS_ID,subvol=/@/.snapshots/1/snapshot^^g" /mnt/etc/fstab
rm /mnt/chroot-install.sh
