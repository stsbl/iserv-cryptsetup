#!/bin/sh

if [ "$(iservdebianrelease)" = "bullseye" ]
then
  cat <<EOT
MkDir 0755 root:root /etc/dropbear-initramfs
Check /etc/dropbear-initramfs/authorized_keys
Check /etc/dropbear-initramfs/config

EOT
else
  cat <<EOT
Remove-R /etc/dropbear-initramfs
MkDir 0755 root:root /etc/dropbear/initramfs
Check /etc/dropbear/initramfs/authorized_keys
Check /etc/dropbear/initramfs/dropbear.conf

EOT
fi
