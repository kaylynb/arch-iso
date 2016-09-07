FROM archlinux

COPY isofiles/etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist

RUN pacman -Sy --noconfirm archlinux-keyring && \
	pacman -Syyu --noconfirm && \
	pacman-db-upgrade && \
	pacman -S --noconfirm git base-devel ca-certificates-mozilla archiso {{ packages.iso.dependencies | join(" ")}} && \
	rm /var/cache/pacman/pkg/*

COPY build-iso.sh /usr/bin/
RUN chmod u+x /usr/bin/build-iso.sh

COPY isofiles/ /isofiles/
