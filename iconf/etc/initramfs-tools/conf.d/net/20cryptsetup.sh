#!/bin/bash

. /usr/lib/iserv/cfg

if [ -n "$InitramfsNetworkInterface" ]
then
  IFACE="$InitramfsNetworkInterface"
  # VLAN interface in $IFACE.$VALID_ID style, enable VLAN support
  # TODO: vlan{num} style is not supported, figure out how to add in a sensible
  # way. Also not supported in initramfs-tools-extras yet.
  if [[ $IFACE =~ ^[^.]+\.[0-9]+$ ]]
  then
    IFS="." IFACE_PARTS=($IFACE)
    printf "VLAN=${IFACE_PARTS[0]}:${IFACE_PARTS[1]}\n"
  fi

  IP=":::::$IFACE:dhcp"

  if [ "$InitramfsNetworkConfigureStatic" ]
  then
    GW_IP="$(ip -json -4 route show default | jq --arg IFACE "$IFACE" -r '.[] | select(.dev==$IFACE) | .gateway')"
    IP="$(netquery "if ip::$GW_IP:mask:host:if" | awk "\$1 == \"$IFACE\" { print \$2 }" | head -n 1 | sed "s/host/$(head -n 1 /etc/hostname)/g")"
  fi

  cat <<EOT
DEVICE=$IFACE
IP=$IP

EOT
else
  echo "Please set InitramfsNetworkInterface in /etc/iserv/config!" >&2
  exit 1
fi
