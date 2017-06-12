# docker_network_samples

Docker単体の機能だけで、ちょっとしたネットワーク環境を作るサンプルです。
Linuxのネットワーク設定周りの動作を確認したいときなどに使えるかもしれません。

"Dockerの使い方備忘録" 的な感は否めません...


## Overview

1. nat

client - router - server な環境


1. bridge

clinet - bridge - router - server な環境
    
※実現方法にだいぶ無理矢理感があります...


1. ipip_vpn

 node2 ==VPN== node1 ==VPN== node3
   |             |             |
client2       client1       client3

※configで拡張可能(かもしれない)


## Requirement

- docker > 1.12.6
- CentOS7 (3.10.0-514.16.1.el7.x86_64) でしか動作確認してません...


## Usage

$ cd docker_network_samples

$ ./docker_network.sh build

$ ./docker_network.sh start {SAMPLE_NAME}

  list of SAMPLE_NAME:

    $ ls -1 samples
    bridge
    ipip_vpn
    nat

$ ./docker_network.sh stop

