FROM archlinux

RUN pacman -Syyu --noconfirm; pacman -S --noconfirm git base-devel archiso {{ packages.dependencies | join(" ")}}; rm /var/cache/pacman/pkg/*

COPY build-iso.sh /usr/bin/
RUN chmod u+x /usr/bin/build-iso.sh

COPY install.sh /isofiles/
