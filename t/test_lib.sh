#!/bin/bash
# -*- coding: utf-8 -*-
# Author: Takashi Hoshino,
# Very simple test runner.
#
[ "$TEST_DEBUG" = "1" ] && set -o xtrace

# 引数のコマンドをそのまま実行して正ならokをカウントする
test=0; ok=0
assert() {
	local args=
	for arg in "$@"; do
		# ex.) $ assert grep "master self" /var/beat/state/cluster
		#   $@ で $1=assert $2=grep $3="master self" となるが、クオートは外れてしまう
		#   evalでそのまま動かすために以下で''を加えて結合している
		if [[ "$arg" =~ " " ]] ; then
			args=$args" '$arg'"
		else
			args=$args" $arg"
		fi
	done
	test=$(( $test + 1 ))
	if eval "$args" ; then
		echo TEST$(printf %02d $test)":OK [${FUNCNAME[1]}] $args  at line" ${BASH_LINENO[0]} >&2
		ok=$(( $ok + 1 ))
	else
		echo TEST$(printf %02d $test)":NG [${FUNCNAME[1]}] $args  at line" ${BASH_LINENO[0]} >&2
	fi
}

# arg1: test_func_name
# if not specified test_func_name, all tests are executed.
do_test() {
	test_name=$1
	if [ -n "$1" ]; then
		echo "only test: $1"
		eval $1
	else
		for test_func in $(declare -f | gawk '/^test_/{print $1}'); do
			$test_func
		done
	fi
}

echo_result() {
	echo result: $ok/$test succeeded
}
