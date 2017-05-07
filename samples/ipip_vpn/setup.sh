#!/bin/bash -ex
# Copyright (c) 2017 Takashi Hoshino (@hijili2)

. ../../lib/docker_utils.sh

# subnetから名前を定義する
_subnet_to_name () {
	subnet=$1; [ -z "subnet" ] && (echo "subnet is empty!"; return 1)
	echo -n $(ipcalc $subnet --network | sed -e 's/NETWORK=//')"/"${subnet#*/}
}
# gateway はnodeが使うものと異なるIPに変える、現状254固定...
_define_gateway () {
	subnet=$1; [ -z "subnet" ] && (echo "subnet is empty!"; return 1)
	echo -n ${subnet} | sed -e 's/\.[0-9]\+\//\.254\//'
}

# 以下の形式で書けばVPNを拡張できる...はず...
echo_config() {
cat <<EOF
# - name は "node{n}" 固定...
# - nodeの下にはclientをベタに固定...
# name  wan                 lan           vpn            connect
node1   192.168.100.101/24  10.0.1.1/24   172.0.1.1/24   node2:node3
node2   192.168.100.102/24  10.0.2.1/24   172.0.1.2/24   node1
node3   192.168.100.103/24  10.0.3.1/24   172.0.1.3/24   node1
EOF
}

do_start() {
	clean_all_user_network

	# ダサいけど、networkの作成、コンテナの起動、VPN構築を3回に分けて実行
	while read name wan lan vpn connect; do
		#DEBUG: printf "%s %s %s %s %s\n" "$name" "$lan" "$vpn" "$connect"
		[[ $name =~ ^# ]] && continue; [ -z "$name" ] && continue
		reset_network $(_subnet_to_name $wan) $(_define_gateway $wan)
		reset_network $(_subnet_to_name $lan) $(_define_gateway $lan)
	done < <(echo_config)

	while read name wan lan vpn connect; do
		[[ $name =~ ^# ]] && continue; [ -z "$name" ] && continue
		run_container $BASE_IMAGE $name \
			$(_subnet_to_name $wan):${wan%/*} \
			$(_subnet_to_name $lan):${lan%/*}
		# base routing and set as NAT
		docker exec $name ip r replace default via 192.168.100.254 dev eth0
		docker exec $name iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

		# add clinet under node
		client_name=client${name#node}
		client_lan=${lan%.*}.99 # change 4th octet number to 99
		run_container $BASE_IMAGE $client_name $(_subnet_to_name $lan):$client_lan
		docker exec $client_name ip r replace default via ${lan%/*} dev eth0
	done < <(echo_config)

	while read name wan lan vpn connect; do
		[[ $name =~ ^# ]] && continue; [ -z "$name" ] && continue
		for target_node in $(echo -n $connect | sed -e 's/:/ /g') ; do
			target_wan=$(grep -e "^$target_node " <(echo_config) | awk '{print $2}')
			target_lan=$(grep -e "^$target_node " <(echo_config) | awk '{print $3}')
			self_num=$(echo -n $name        | sed -e 's/node//')
			peer_num=$(echo -n $target_node | sed -e 's/node//')
			tun_name=tun${self_num}to${peer_num}

			# VPN
			docker exec $name ip tunnel add $tun_name mode ipip \
				remote ${target_wan%/*} local ${wan%/*}
			docker exec $name ip link set $tun_name up
			docker exec $name ip addr add $vpn dev $tun_name

			# routing
			# target_lan_net: 10.0.0.1/24 -> 10.0.0.0/24
			target_lan_net=$(ipcalc $target_lan --network | sed -e 's/NETWORK=//')"/"${target_lan#*/}
			docker exec $name ip route add $target_lan_net dev $tun_name
		done
	done < <(echo_config)
}

do_stop() {
	while read name wan lan vpn connect; do
		[[ $name =~ ^# ]] && continue; [ -z "$name" ] && continue
		clean_container $name
	done < <(echo_config)
}

show_net() {
	cat<<EOF
Network structure
         +--------------------------------+--------------------------------+
         |                                |                                |
192.168.100.102/24                192.168.100.101/24               192.168.100.103/24
         |                                |                                |
     +---+---+    VPN (IPIP tunnel)   +---+---+   VPN (IPIP tunnel)    +---+---+
     | node2 | ---------------------- | node1 | ---------------------- | node3 |
     +---+---+ 172.0.1.2    172.0.1.1 +---+---+ 172.0.1.1    172.0.3.1 +---+---+
         |                                |                                |
    10.0.2.1/24                      10.0.1.1/24                      10.0.3.1/24
         |                                |                                |
         |                                |                                |
    10.0.2.99/24                     10.0.1.99/24                     10.0.3.99/24
         |                                |                                |
    +----+----+                      +----+----+                      +----+----+
    | client2 |                      | client1 |                      | client3 |
    +---------+                      +---------+                      +---------+

EOF
}

case "$1" in
	start)
		do_start ;;
	sh|login)
		login_container $2 ;;
	stop)
		do_stop ;;
	show)
		show_net ;;
	*)
		echo "$0 {build|start|stop}"; exit 1 ;;
esac

echo "operation finished!"
