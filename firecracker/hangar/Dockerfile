FROM debian:13-slim
RUN apt-get -qq update && DEBIAN_FRONTEND=noninteractive apt-get -qq install -y --no-install-recommends \
    iproute2 iptables curl ca-certificates e2fsprogs procps jq && apt-get clean && rm -rf /var/lib/apt/lists/*
