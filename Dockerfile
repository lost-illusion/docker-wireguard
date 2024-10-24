# syntax=docker/dockerfile:1

FROM golang:1.22.3 as awg
COPY ./amneziawg-go /awg
WORKDIR /awg
RUN go mod download && \
    go mod verify && \
    go build -ldflags '-linkmode external -extldflags "-fno-PIC -static"' -v -o /usr/bin

FROM ghcr.io/linuxserver/baseimage-alpine:3.20

# set version label
ARG BUILD_DATE
ARG VERSION
ARG WIREGUARD_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thespad"

COPY ./amneziawg-tools /app/awg-tools

RUN \
  echo "**** install dependencies ****" && \
  apk add --no-cache --virtual=build-dependencies \
    build-base \
    elfutils-dev \
    git \
    linux-headers && \
  apk add --no-cache \
    bc \
    coredns \
    grep \
    iproute2 \
    iptables \
    iptables-legacy \
    ip6tables \
    iputils \
    kmod \
    libcap-utils \
    libqrencode-tools \
    net-tools \
    openresolv && \
  # wireguard-tools && \
  # echo "wireguard" >> /etc/modules && \
  cd /sbin && \
  for i in ! !-save !-restore; do \
    rm -rf iptables$(echo "${i}" | cut -c2-) && \
    rm -rf ip6tables$(echo "${i}" | cut -c2-) && \
    ln -s iptables-legacy$(echo "${i}" | cut -c2-) iptables$(echo "${i}" | cut -c2-) && \
    ln -s ip6tables-legacy$(echo "${i}" | cut -c2-) ip6tables$(echo "${i}" | cut -c2-); \
  done && \
  echo "**** install wireguard-tools ****" && \
  cd /app && \
  cd awg-tools && \
  sed -i 's|\[\[ $proto == -4 \]\] && cmd sysctl -q net\.ipv4\.conf\.all\.src_valid_mark=1|[[ $proto == -4 ]] \&\& [[ $(sysctl -n net.ipv4.conf.all.src_valid_mark) != 1 ]] \&\& cmd sysctl -q net.ipv4.conf.all.src_valid_mark=1|' src/wg-quick/linux.bash && \
  make -C src -j$(nproc) && \
  make -C src install && \
  chmod +x /usr/bin/awg /usr/bin/awg-quick && \
  ln -s /usr/bin/awg /usr/bin/wg && \
  ln -s /usr/bin/awg-quick /usr/bin/wg-quick && \
  rm -rf /etc/wireguard && \
  ln -s /config/wg_confs /etc/wireguard && \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** clean up ****" && \
  apk del --no-network build-dependencies && \
  rm -rf \
    /tmp/*

# add local files
COPY ./docker-wireguard/root /
COPY --from=awg /usr/bin/amneziawg-go /usr/bin/amneziawg-go

# ports and volumes
EXPOSE 51820/udp