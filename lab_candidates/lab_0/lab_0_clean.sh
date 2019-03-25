#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
# set -euo pipefail
# IFS=$'\n\t'

# Debug mode
# set -xv

na_prefix=lab_ns
bridge_prefix=lab_bridge
veth_prefix=lab_veth

# 1 Delete addresses from the peer interfaces within each namespace
ip netns exec "${na_prefix}_1" \
    ip address del 10.0.0.1/24 dev "${veth_prefix}_ns_1"
ip netns exec "${na_prefix}_2" \
    ip address del 10.0.0.2/24 dev "${veth_prefix}_ns_2"

# 2- Shutdown the veth interfaces and peers
ip link set "${veth_prefix}_1" down
ip link set "${veth_prefix}_2" down
ip netns exec "${na_prefix}_1" \
    ip link set "${veth_prefix}_ns_1" down
ip netns exec "${na_prefix}_2" \
    ip link set "${veth_prefix}_ns_2" down

# 2- Detach veth interfaces from the bridge
ip link set "${veth_prefix}_1" nomaster
ip link set "${veth_prefix}_2" nomaster

# 3- Delete 2 veth interfaces, 1 for each namespace
ip link del name "${veth_prefix}_1"
ip link del name "${veth_prefix}_2"

# 4- Delete main bridge 
ip link set "${bridge_prefix}_main" down
ip link del name "${bridge_prefix}_main"

# 5- Delete namespaces
ip netns del "${na_prefix}_1"
ip netns del "${na_prefix}_2"


