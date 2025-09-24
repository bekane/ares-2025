#!/bin/bash


ip netns del host1
ip netns del host2
ip netns del internet

modprobe -r ipip

exit 

# Create the namespaces
ip netns add host1
ip netns add host2
ip netns add internet

# Create the topology
ip link add veth0 type veth peer name veth1
ip link add veth2 type veth peer name veth3

ip link set veth0 netns host1
ip link set veth1 netns internet
ip link set veth2 netns internet
ip link set veth3 netns host2

# Host1
ip netns exec host1 ip addr add 10.10.1.2/24 dev veth0
ip netns exec host1 ip link set veth0 up
ip netns exec host1 ip link set lo up

# Host2
ip netns exec host2 ip addr add 172.16.20.2/24 dev veth3
ip netns exec host2 ip link set veth3 up
ip netns exec host2 ip link set lo up

# Internet
ip netns exec internet ip addr add 10.10.1.1/24 dev veth1
ip netns exec internet ip link set veth1 up
ip netns exec internet ip addr add 172.16.20.1/24 dev veth2
ip netns exec internet ip link set veth2 up
ip netns exec internet ip link set lo up
ip netns exec internet sysctl -w net.ipv4.ip_forward=1

# Add routes so tunnel endpoints can talk
ip netns exec host1 ip route add 172.16.20.0/24 via 10.10.1.1
ip netns exec host2 ip route add 10.10.1.0/24 via 172.16.20.1

# Create GRE tunnel on host1
ip netns exec host1 ip tunnel add tap0 mode ipip local 10.10.1.2 remote 172.16.20.2 ttl 255
ip netns exec host1 ip addr add 192.168.10.1/30 dev tap0
ip netns exec host1 ip link set tap0 up

# Create GRE tunnel on host2
# FIXED typo 176 → 172
ip netns exec host2 ip tunnel add tap0 mode ipip local 172.16.20.2 remote 10.10.1.2 ttl 255
ip netns exec host2 ip addr add 192.168.10.2/30 dev tap0
ip netns exec host2 ip link set tap0 up

exit 0

