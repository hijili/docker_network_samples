#!/bin/bash -ex
# Copyright (c) 2017 Takashi Hoshino (@hijili2)

. ../../lib/docker_utils.sh

do_start() {
	reset_network internet 192.168.100.254/24
	reset_network lan 10.0.0.254/24

	run_container $BASE_IMAGE server internet:192.168.100.100
	run_container $BASE_IMAGE router internet:192.168.100.1 lan:10.0.0.1
	run_container $BASE_IMAGE client lan:10.0.0.100

	docker exec client ip r replace default via 10.0.0.1
	docker exec router ip r replace default via 192.168.100.254
	docker exec router iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
}

do_stop() {
	clean_container server
	clean_container router
	clean_container client
}

_tproxy() {
	docker exec server \
		iptables -t mangle -F MY_PROXY && \
		iptables -t mangle -X MY_PROXY

	docker exec server \
	iptables -t mangle -N MY_PROXY && \
	iptables -t mangle -A PREROUTING -j MY_PROXY && \
	iptables -t mangle -A MY_PROXY -p tcp --dport 80 -j TPROXY \
		--tproxy-mark 1 --on-port 30080 && \
	ip rule add fwmark 1 lookup 333 && \
	ip route add local default dev lo table 333 && \

	docker cp tanuki server:/
	docker exec server ./tanuki
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

