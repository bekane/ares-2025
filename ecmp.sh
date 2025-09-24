#!/bin/bash
set -x
set -e

# Nettoyage
ip -all netns del 2>/dev/null || true

# Création des namespaces
ip netns add ns1
ip netns add ns2
ip netns add r1
ip netns add r2

# Création des veth pairs
ip link add veth-ns1-r1 type veth peer name veth-r1-ns1
ip link add veth-ns1-r2 type veth peer name veth-r2-ns1
ip link add veth-r1-ns2 type veth peer name veth-ns2-r1
ip link add veth-r2-ns2 type veth peer name veth-ns2-r2

# Attacher aux namespaces
ip link set veth-ns1-r1 netns ns1
ip link set veth-ns1-r2 netns ns1
ip link set veth-r1-ns1 netns r1
ip link set veth-r2-ns1 netns r2
ip link set veth-r1-ns2 netns r1
ip link set veth-ns2-r1 netns ns2
ip link set veth-r2-ns2 netns r2
ip link set veth-ns2-r2 netns ns2

# Adressage IP
ip netns exec ns1 ip addr add 10.0.1.1/24 dev veth-ns1-r1
ip netns exec ns1 ip addr add 10.0.2.1/24 dev veth-ns1-r2
ip netns exec r1 ip addr add 10.0.1.2/24 dev veth-r1-ns1
ip netns exec r1 ip addr add 10.0.3.1/24 dev veth-r1-ns2
ip netns exec r2 ip addr add 10.0.2.2/24 dev veth-r2-ns1
ip netns exec r2 ip addr add 10.0.4.1/24 dev veth-r2-ns2
ip netns exec ns2 ip addr add 10.0.3.2/24 dev veth-ns2-r1
ip netns exec ns2 ip addr add 10.0.4.2/24 dev veth-ns2-r2

# Activer les interfaces
for ns in ns1 ns2 r1 r2; do
  ip netns exec $ns ip link set lo up
    for iface in $(ip netns exec $ns ip -o link show | awk -F': ' '/veth/{print $2}' | cut -d@ -f 1); do
    ip netns exec $ns ip link set $iface up
  done
done

# Activer le forwarding dans r1 et r2
ip netns exec r1 sysctl -w net.ipv4.ip_forward=1
ip netns exec r2 sysctl -w net.ipv4.ip_forward=1

# Routes multipath dans ns1
ip netns exec ns1 ip route add 10.0.3.0/24 \
    nexthop via 10.0.1.2 dev veth-ns1-r1 \
    nexthop via 10.0.2.2 dev veth-ns1-r2
ip netns exec ns1 ip route add 10.0.4.0/24 \
    nexthop via 10.0.1.2 dev veth-ns1-r1 \
    nexthop via 10.0.2.2 dev veth-ns1-r2

# Routes retour dans ns2
ip netns exec ns2 ip route add 10.0.1.0/24 via 10.0.3.1 dev veth-ns2-r1
ip netns exec ns2 ip route add 10.0.2.0/24 via 10.0.4.1 dev veth-ns2-r2

echo "Setup terminé. Teste avec :"
echo "ip netns exec ns1 ping -c3 10.0.3.2"

