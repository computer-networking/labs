#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Debug mode
set -xv

# Configurable terminal bin
TERM_BIN=/usr/bin/xfce4-terminal

# Configurable prefixes
na_prefix=lab_ns
bridge_prefix=lab_bridge
veth_prefix=lab_veth

# 1- Create namespaces
ip netns add "${na_prefix}_1"
ip netns add "${na_prefix}_2"

# 2- Start loopback interfaces for each ns
ip netns exec "${na_prefix}_1" ip link set lo up
ip netns exec "${na_prefix}_2" ip link set lo up

# 3- List namespaces
ls -l /var/run/netns/
ip netns list

# 4- Show interfaces for each namespace
ip netns exec "${na_prefix}_1" ip link show
ip netns exec "${na_prefix}_2" ip link show

# 5- Create main bridge 
ip link add name "${bridge_prefix}_main" type bridge
ip link set "${bridge_prefix}_main" up

# 6- Create 2 veth interfaces, 1 for each namespace
ip link add \
    name "${veth_prefix}_1" \
    type veth \
    peer name "${veth_prefix}_ns_1"
ip link add \
    name "${veth_prefix}_2" \
    type veth \
    peer name "${veth_prefix}_ns_2"

# 7- Attach the main veth interfaces into the bridge
ip link set "${veth_prefix}_1" master "${bridge_prefix}_main"
ip link set "${veth_prefix}_2" master "${bridge_prefix}_main"
ip link set "${veth_prefix}_1" up
ip link set "${veth_prefix}_2" up

# 8- Attach the veth peer interfaces into the target namespace
ip link set "${veth_prefix}_ns_1" netns "${na_prefix}_1"
ip link set "${veth_prefix}_ns_2" netns "${na_prefix}_2"
ip netns exec "${na_prefix}_1" \
    ip link set "${veth_prefix}_ns_1" up
ip netns exec "${na_prefix}_2" \
    ip link set "${veth_prefix}_ns_2" up

# 9- Assign addresses to the peer interfaces within each namespace
ip netns exec "${na_prefix}_1" \
    ip address add 10.0.0.1/24 dev "${veth_prefix}_ns_1"
ip netns exec "${na_prefix}_2" \
    ip address add 10.0.0.2/24 dev "${veth_prefix}_ns_2"

# 10- Show all interfaces within all net ns
ip -all netns exec ip address show

# 11- Open terminals for each namespace if valid.
if [ -x "$TERM_BIN" ] ; then
    ip netns exec "${na_prefix}_1" "$TERM_BIN" &
    ip netns exec "${na_prefix}_2" "$TERM_BIN" &
fi
