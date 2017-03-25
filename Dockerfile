FROM docker.io/centos:centos7
MAINTAINER hijili2 <shooting.shooting.shooter@googlemail.com>
RUN yum -y update
RUN yum -y install iproute tcpdump bridge-utils telnet less
RUN yum -y install bind-utils emacs-nox
RUN yum -y install httpd rsyslog
ENV TERM xterm
