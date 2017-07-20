#!/bin/bash

# Run a container witout network
contid=$(docker run -d --net=none busybox:latest /bin/sleep 10000000)

# find its id
pid=$(docker inspect -f '{{ .State.Pid }}' $contid)

# create namespace since docker doesn't create it
ln  -s /proc/$pid/ns/net /var/run/netns/ns-$pid

# netns allow us to run ip inside `netns`
ip netns exec ns-$pid ip link

# create an veth pair
ip link add eth0-ns-$pid type veth peer name veth-ns-$pid
# assign it to namespace $pid
ip link set eth0-ns-$pid netns ns-$pid

ip netns exec ns-$pid ip link set dev eth0-ns-$pid down
ip netns exec ns-$pid ip link set dev eth0-ns-$pid name eth1
ip netns exec ns-$pid ip link set dev eth1 up
ip link set dev veth-ns-$pid up

# add other end(on host) to docker0 bridge
 ip link set veth-ns-$pid master docker0

# assign an ip for the ethernet inside namespace
ip netns exec ns-$pid ip addr add 172.17.0.10/24 dev eth1
# ip addr add 172.17.0.10/24 dev veth-ns-$pid
# when we need to delete the address
# ip addr del 172.17.0.10/24 dev veth-ns-$pid

# view ip link
ip netns exec ns-$pid ip link
