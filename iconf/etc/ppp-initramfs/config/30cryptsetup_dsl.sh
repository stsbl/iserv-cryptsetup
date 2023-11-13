#!/bin/sh
set -e

PPPD_PEER=dsl
PPPD_IFACE=eth0

if dsl
then
  TRAILER=''
  PPPD_IFACE="$(grep -oE '^plugin rp-pppoe\.so .+$' /etc/ppp/peers/dsl | awk '{ print $3 }')" || { echo "Could not determine PPPD_IFACE!" >&2; exit 1; }
else
  TRAILER='#'
fi

cat <<EOT
#
# The filename of the peer configuration from /etc/ppp/peers.
#
${TRAILER}PPPD_PEER=${PPPD_PEER}

#
# The physical interface for the PPPoE concentrator.
#
${TRAILER}PPPD_IFACE=${PPPD_IFACE}

EOT
