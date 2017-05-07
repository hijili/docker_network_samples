#!/bin/bash -ex
# Copyright (c) 2017 Takashi Hoshino (@hijili2)
# Released under the MIT license

if [ ${EUID:-${UID}} != 0 ]; then
	echo you must exec by sudo!
	exit 1
fi

. lib/docker_utils.sh

STAT_FILE=.stat

case "$1" in
	build)
		build_image ;;
	start)
		[ -z "$2" ] && (echo "Input sample_name!"; exit 1)
		sample_name=$2
		echo $sample_name > $STAT_FILE
		(cd samples/$sample_name ; ./setup.sh start)
		;;
	stop)
		[ ! -f $STAT_FILE ] && (echo "Input sample_name!"; exit 1)
		sample_name=$(cat $STAT_FILE)
		(cd samples/$sample_name; ./setup.sh stop)
		;;
	sh|login)
		[ -z "$2" ] && (echo "Input container_name!"; exit 1)
		container_name=$2
		login_container $container_name
		;;
	*)
		echo "$0 {build|start|sh|login|stop}"; exit 1 ;;
esac
