#!/bin/bash -ex
# Copyright (c) 2017 Takashi Hoshino (@hijili2)

. ../../lib/docker_utils.sh

do_start() {
	reset_network wan 192.168.100.254/24
	reset_network lan1 10.0.0.254/24
	reset_network lan2 100.0.0.254/24 # dummy

	run_container $BASE_IMAGE server wan:192.168.100.100
	run_container $BASE_IMAGE router wan:192.168.100.1 lan1:10.0.0.1
	run_container $BASE_IMAGE bridge lan1:10.0.0.100 lan2:100.0.0.1
	run_container $BASE_IMAGE client lan2:100.0.0.2

	docker exec router ip r replace default via 192.168.100.254
	docker exec router iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

	docker exec bridge ip addr flush dev eth0
	docker exec bridge ip addr flush dev eth1
	docker exec bridge brctl addbr br0
	docker exec bridge brctl addif br0 eth0
	docker exec bridge brctl addif br0 eth1
	docker exec bridge ip link set br0 up

	docker exec client ip addr flush dev eth0
	docker exec client ip addr add 10.0.0.200/24 dev eth0
	docker exec client ip r add default via 10.0.0.1 dev eth0
}

do_stop() {
	clean_container server
	clean_container router
	clean_container bridge
	clean_container client
}

_tproxy() {
	e="docker exec bridge"
	$e iptables -t mangle -F MY_PROXY || :
	$e iptables -t mangle -X MY_PROXY || :
	$e iptables -t mangle -N MY_PROXY
	$e iptables -t mangle -A PREROUTING -j MY_PROXY
	$e iptables -t mangle -A MY_PROXY -p tcp --dport 80 \
		-j TPROXY --tproxy-mark 1 --on-port 30080

	$e ip rule add fwmark 1 lookup 333
	$e ip route add local default dev lo table 333

	docker cp tanuki bridge:/
	#docker exec server ./tanuki
}

case "$1" in
	start)
		do_start $2 ;;
	sh|login)
		login_container $2 ;;
	stop)
		do_stop $2 ;;
	test)
		_tproxy;;
	*)
		echo "$0 {start|stop|sh}"; exit 1 ;;
esac

