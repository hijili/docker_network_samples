# docker_network_samples

Docker単体の機能だけでちょっとしたネットワーク環境を作るサンプルです


## Overview

1. nat

TBD...AAA

1. bridge


1. ipip_vpn


## Requirement

- docker > 1.12.6
- CentOS7 (3.10.0-514.16.1.el7.x86_64) でしか動作確認してません...

## Usage

$ ./docker_network.sh build
$ ./docker_network.sh start {SAMPLE_NAME}

  SAMPLE_NAME:

    $ ls -1 samples
    bridge
    ipip_vpn
    nat

$ ./docker_network.sh stop