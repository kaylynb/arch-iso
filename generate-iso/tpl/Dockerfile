FROM archlinux/base

COPY isofiles/etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist

RUN pacman -Sy --noconfirm archlinux-keyring && \
	pacman -S --noconfirm ca-certificates-mozilla && \
	pacman -Syu --noconfirm && \
	pacman -S --noconfirm git base-devel archiso {{ packages.iso.dependencies | join(" ")}}

COPY build-iso.sh /usr/bin/
RUN chmod u+x /usr/bin/build-iso.sh

COPY isofiles/ /isofiles/
