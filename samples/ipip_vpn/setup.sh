#!/bin/bash -ex
# Copyright (c) 2017 Takashi Hoshino (@hijili2)

. ../../lib/docker_utils.sh

_subnet_to_name () {
	subnet=$1; [ -z "subnet" ] && (echo "subnet is empty!"; return 1)
	echo -n $(ipcalc $subnet --network | sed -e 's/NETWORK=//')"/"${subnet#*/}
}
# gateway はnodeが使うものと異なるIPに変える
_define_gateway () {
	subnet=$1; [ -z "subnet" ] && (echo "subnet is empty!"; return 1)
	echo -n ${subnet} | sed -e 's/\.[0-9]\+\//\.254\//'
}

do_start() {
	conf_file=$1 # file
	[ -f "$conf_file" ] || (echo "config file is needed!"; exit 1)

	# ダサいけど、networkの作成、コンテナの起動、VPN構築を3回に分けて実行

	while read name wan lan vpn connect; do
		#DEBUG: printf "%s %s %s %s %s\n" "$name" "$lan" "$vpn" "$connect"
		[[ $name =~ ^# ]] && continue
		[ -z $name ] && continue
		reset_network $(_subnet_to_name $wan) $(_define_gateway $wan)
		reset_network $(_subnet_to_name $lan) $(_define_gateway $lan)
	done < $conf_file

	while read name wan lan vpn connect; do
		#DEBUG: printf "%s %s %s %s %s\n" "$name" "$lan" "$vpn" "$connect"
		[[ $name =~ ^# ]] && continue
		[ -z $name ] && continue
		run_container $BASE_IMAGE $name \
			$(_subnet_to_name $wan):${wan%/*} \
			$(_subnet_to_name $lan):${lan%/*}
	done < $conf_file

	while read name wan lan vpn connect; do
		[[ $name =~ ^# ]] && continue
		[ -z $name ] && continue
		for target_node in $(echo -n $connect | sed -e 's/:/ /g') ; do
			target_wan=$(grep -e "^$target_node" $conf_file| awk '{print $2}')
			target_lan=$(grep -e "^$target_node" $conf_file| awk '{print $3}')
			self_num=$(echo -n $name        | sed -e 's/node//')
			peer_num=$(echo -n $target_node | sed -e 's/node//')
			tun_name=tun${self_num}to${peer_num}

			# VPN
			docker exec $name ip tunnel add $tun_name mode ipip remote ${target_wan%/*} local ${wan%/*}
			docker exec $name ip link set $tun_name up
			docker exec $name ip addr add $vpn dev $tun_name

			# routing
			# target_lan_net: 10.0.0.1/24 -> 10.0.0.0/24
			target_lan_net=$(ipcalc $target_lan --network | sed -e 's/NETWORK=//')"/"${target_lan#*/}
			docker exec $name ip route add $target_lan_net dev $tun_name
		done
	done < $conf_file

#	_do_test
}

_do_test() {
	docker exec node1 ip r replace default via 192.168.100.254 dev eth0

	# basic,active node1配下で
	docker run -d --cap-add NET_ADMIN --cap-add SYS_ADMIN --name node4 \
		--hostname node4 --net 10.0.1.0/24 --ip 10.0.1.100 \
		${REPOSITORY}:${TAG} /bin/sh -c "while true; do sleep 1; done"
	docker exec node4 ip r replace default via 10.0.1.1

	docker run -d --cap-add NET_ADMIN --cap-add SYS_ADMIN --name node5 \
		--hostname node5 --net $WAN_NAME --ip 192.168.100.200 \
		${REPOSITORY}:${TAG} /bin/sh -c "while true; do sleep 1; done"
	docker exec node5 ip r replace default via 192.168.100.254

	docker exec node1 iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
	# 以上

	docker exec node5 httpd || :
	return 0

	# ここからentry模造   node2配下でやる

	# nodeE がentry
	docker run -d --cap-add NET_ADMIN --cap-add SYS_ADMIN --name nodeE \
		--hostname nodeE --net 10.0.2.0/24 --ip 10.0.2.100 \
		${REPOSITORY}:${TAG} /bin/sh -c "while true; do sleep 1; done"

	# eth1作ってeth0をまずbridge
	docker exec nodeE brctl addbr eth1
	docker exec nodeE brctl addif eth1 eth0
	docker exec nodeE ip link set eth1 up

	# 2回connectしたってそりゃダメ
	# docker network connect 10.0.2.0/24 nodeE

	# 適当な nodeE配下のダミーネットワーク nodeEnet を作ってみる
	# XXX: 同じサブネットのを作ろうとするとエラーになるので適当な値で作る
	docker network create --subnet "1.0.2.0/24" nodeEnet \
		-o com.docker.network.bridge.name=br-nodeEnet \
		-o com.docker.network.bridge.enable_ip_masquerade=false

	# nodeE配下に nodeE1 (entry配下のPC)
	# XXX: ip を省略してもipついてしまう...
	docker run -d --cap-add NET_ADMIN --cap-add SYS_ADMIN --name nodeE1 \
		--hostname nodeE1 --net nodeEnet --ip "" hijili/docker_network:1.0 /bin/sh -c "while true; do sleep 1; done"
	docker exec nodeE1 ip addr flush dev eth0 # とりあえず消す

	# XXX: eth1が既にあると怒られる... もういっかいやるとeth2で作られる...
	docker network connect nodeEnet nodeE || :
	docker network connect nodeEnet nodeE
	docker exec nodeE ip addr flush dev eth2 # とりあえず消す
	docker exec nodeE brctl addif eth1 eth2

	docker exec nodeE1 ip addr add 10.0.2.200/24 dev eth0

	# これを消したら多分思い通り動作した...
	# iptables -t nat -D POSTROUTING -s 10.0.2.0/24 ! -o br-10.0.2.0:24 -j MASQUERADE
	# 10.0.2.0/24 のネットワークでもmasqをしなきゃよさそう isolatedとかとの関係...
}
_do_test_stop() {
	for name in node4 node5 nodeE nodeE1 ; do
		clean_container $name
	done
	docker network rm nodeEnet || :
}

do_stop() {
	conf_file=$1 # file
	[ -f "$conf_file" ] || (echo "$conf_file is illegal!"; exit 1)
	while read name lan vpn connect; do
		[[ $name =~ ^# ]] && continue
		[ -z "$name" ] && continue
		clean_container $name
	done < $conf_file

	#_do_test_stop
}

case "$1" in
	start)
		do_start $2 ;;
	sh|login)
		login_container $2 ;;
	stop)
		do_stop $2 ;;
	*)
		echo "$0 {build|start|stop}"; exit 1 ;;
esac

