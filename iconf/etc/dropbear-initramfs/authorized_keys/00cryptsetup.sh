#!/bin/bash

. /usr/lib/iserv/cfg

for Act in "${DropbearAuthorizedAccounts[@]}"
do
  if ! getent passwd "$Act"
  then
    echo "Invalid account $Act in DropbearAuthorizedAccounts!" >&2
    exit 1
  fi

  KEY_FILE="$(getent passwd "$Act" | cut -d: -f6)/.ssh/authorized_keys"

  if [ -f "$KEY_FILE" ]
  then
    cat "$KEY_FILE" 
  fi
done
