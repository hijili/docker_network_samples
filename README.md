# docker_network_samples

Docker単体の機能だけで、ちょっとしたネットワーク環境を作るサンプルです。  
Linuxのネットワーク設定周りの動作を確認したいときなどに使えるかもしれません。
  
"Dockerの使い方備忘録" 的な感は否めません...


## Overview

以下のようなsample環境を作ります

### nat

client - router - server


### bridge

clinet - bridge - router - server
   
※実現方法にだいぶ無理矢理感があります...


### ipip_vpn

~~~
 node2 ==VPN== node1 ==VPN== node3
   |             |             |
client2       client1       client3
~~~

※vpnと言っても暗号化無し
※configで拡張可能(かもしれない)


## Requirement

- docker > 1.12.6
- CentOS7 (Kernel 3.10.0) でしか動作確認してません...


## Usage

```
$ cd docker_network_samples

$ sudo ./docker_network.sh build

$ sudo ./docker_network.sh start {SAMPLE_NAME}

  list of SAMPLE_NAME:

    $ ls -1 samples
    bridge
    ipip_vpn
    nat

コンテナに入る
$ sudo ./docker_network.sh sh {CONTAINER_NAME}

$ sudo ./docker_network.sh stop
```

デバッグ出力が欲しいとき

```
$ sudo DEBUG=1 ./docker_network.sh start {SAMPLE_NAME}
```
