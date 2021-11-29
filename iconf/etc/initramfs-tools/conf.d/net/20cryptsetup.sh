#!/bin/bash

. /usr/lib/iserv/cfg

if [ -n "$InitramfsNetworkInterface" ]
then
cat <<EOT
DEVICE=$InitramfsNetworkInterface
IP=:::::$InitramfsNetworkInterface:dhcp

EOT
else
  echo "Please set InitramfsNetworkInterface in /etc/iserv/config!" >&2
  exit 1
fi
