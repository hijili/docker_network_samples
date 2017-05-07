#!/bin/bash -ex
# Copyright (c) 2017 Takashi Hoshino (@hijili2)

. ../../lib/docker_utils.sh

do_start() {
	clean_all_user_network

	reset_network wan 192.168.100.254/24
	reset_network lan 10.0.0.254/24

	run_container $BASE_IMAGE server wan:192.168.100.100
	run_container $BASE_IMAGE router wan:192.168.100.1 lan:10.0.0.1
	run_container $BASE_IMAGE client lan:10.0.0.100

	docker exec client ip r replace default via 10.0.0.1
	docker exec router ip r replace default via 192.168.100.254
	docker exec router iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
}

do_stop() {
	clean_container server
	clean_container router
	clean_container client
	clean_all_user_network
}

case "$1" in
	start)
		do_start $2 ;;
	sh|login)
		login_container $2 ;;
	stop)
		do_stop $2 ;;
	*)
		echo "$0 {start|stop|sh}"; exit 1 ;;
esac

echo "operation finished!"
