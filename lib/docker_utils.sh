#!/bin/bash
# Copyright (c) 2017 Takashi Hoshino (@hijili2)

BASE_IMAGE=hijili/network_base
build_image() {
	docker build -t $BASE_IMAGE $1
}

# arg1: container name
clean_container() {
	local name=$1; [ -z "$name" ] && (echo "input container name"; return 1)
	[ -n "$(docker ps -q -f name=$name)" ]    && docker stop $name
	[ -n "$(docker ps -a -q -f name=$name)" ] && docker rm $name
	return 0
}

# arg1: container name | image name
# If running container is found, exec sh in the container.
# If image name is specified, run container and exec sh.
login_container() {
	local name=$1; [ -z "$name" ] && return 1
	if [ -n "$(docker ps -q -f name=$name)" ]; then
		docker exec -it $name /bin/sh
	else
		[ -n "$(docker ps -a -q -f name=$name)" ] && docker rm $name
		docker run --rm -it $name /bin/sh
	fi
}

# arg1: network name
# arg2: subnet (xxx.xxx.xxx.xxx/xx, address is set as gateway)
reset_network() {
	local net_name=$1; [ -z "$net_name" ] && return 1
	local subnet=$2; [ -z "$subnet" ] && return 1

	docker network inspect $net_name >/dev/null 2>&1 && docker network rm $net_name
	_create_network $net_name $subnet
}
add_network() {
	local net_name=$1; [ -z "$net_name" ] && return 1
	local subnet=$2; [ -z "$subnet" ] && return 1
	docker network inspect $net_name >/dev/null 2>&1 && return 0
	_create_network $net_name $subnet
}
_create_network() {
	net_name=$1; subnet=$2
	#local br_name=$(echo ${net_name/} | sed -e 's/\//:/g') # "/" cannot be used as bridge name
	local br_name=$(echo ${net_name%/*}) # "/" cannot be used as bridge name
	docker network create --subnet=$subnet --gateway=${subnet%/*} $net_name \
		-o com.docker.network.bridge.name=br$br_name

	#-o com.docker.network.bridge.enable_ip_masquerade=false
}

# arg1: image_name
# arg2: container_name
# arg3...: list of net_info (option)
#       "net_info" is defined as {net_name}:{container_ip}
run_container() {
	image_name=$1; [ -z "$image_name" ] && return 1
	cont_name=$2;  [ -z "$cont_name" ] && return 1
	shift; shift; net_info=("$@")

	# If "net_info" is not set, connect on default docker bridge
	local net_option=
	if [ -z "$net_info" ]; then
		net_option="--net bridge"
	else
		_info=${net_info[0]}; net_info=("${net_info[@]:1}") # pop
		_net_name=${_info%:*} ; _self_ip=${_info#*:}
		net_option="--net $_net_name"
		[ -n "$_self_ip" ] && net_option=$net_option" --ip $_self_ip"
	fi

	clean_container $cont_name
	docker run -d --cap-add NET_ADMIN --cap-add SYS_ADMIN \
		--name $cont_name --hostname $cont_name \
		$net_option \
		$image_name /bin/sh -c "while true; do sleep 1; done"

	# add optional network
	for _info in ${net_info[@]}; do
		_net_name=${_info%:*} ; _self_ip=${_info#*:}
		docker network connect \
			$( [ -n "$_self_ip" ] && echo -n "--ip $_self_ip" ) \
			$_net_name $cont_name
	done
}
