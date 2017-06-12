#!/bin/bash
# Copyright (c) 2017 Takashi Hoshino (@hijili2)

if [ ${EUID:-${UID}} != 0 ]; then
	echo you must exec by sudo!
	exit 1
fi

testdir=$(dirname "${0}")
expr "$testdir" : "/.*" > /dev/null || testdir=$(cd "${testdir}" && pwd)
cd $testdir

. test_lib.sh

# ないよりマシ程度なテスト

test_nat() {
	cd $testdir/..
	assert ./docker_network.sh start nat

	assert docker exec client ping -c 1 -i 2 10.0.0.1
	assert docker exec client ping -c 1 -i 2 192.168.100.100
	assert ! docker exec server ping -c 1 -i 2 10.0.0.1

	assert ./docker_network.sh stop
}

test_bridge() {
	cd $testdir/..
	assert ./docker_network.sh start bridge

	assert docker exec client ping -c 1 -i 2 10.0.0.1
	assert docker exec client ping -c 1 -i 2 192.168.100.100

	assert docker exec bridge ping -c 1 -i 2 10.0.0.1
	assert docker exec bridge ping -c 1 -i 2 10.0.0.200
	assert docker exec bridge ping -c 1 -i 2 192.168.100.100

	assert docker exec router ping -c 1 -i 2 10.0.0.200
	assert docker exec router ping -c 1 -i 2 192.168.100.100

	assert ! docker exec server ping -c 1 -i 2 10.0.0.1
	assert ! docker exec server ping -c 1 -i 2 10.0.0.200

	assert ./docker_network.sh stop
}

test_ipip_vpn() {
	cd $testdir/..
	assert ./docker_network.sh start ipip_vpn

	# TODO: test from config...
	assert docker exec client1 ping -c 1 -i 2 10.0.2.99
	assert docker exec client1 ping -c 1 -i 2 10.0.3.99

	assert docker exec client2 ping -c 1 -i 2 10.0.1.99
	assert ! docker exec client2 ping -c 1 -i 2 10.0.3.99

	assert docker exec client3 ping -c 1 -i 2 10.0.1.99
	assert ! docker exec client3 ping -c 1 -i 2 10.0.2.99

	# If routing for node2 and node3 are set, ping will be success.
	docker exec node2 ip r add 10.0.3.0/24 dev tun2to1
	docker exec node3 ip r add 10.0.2.0/24 dev tun3to1
	assert docker exec client2 ping -c 1 -i 2 10.0.3.99
	assert docker exec client3 ping -c 1 -i 2 10.0.2.99

	assert ./docker_network.sh stop
}

{
cd $testdir/..
./docker_network.sh stop
}

do_test $1
echo_result
