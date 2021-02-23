#!/bin/ash

if [ "$(wget --quiet --tries=1 --spider "http://${HOSTNAME}:81/proxy.pac"; echo $?)" -ne 0 ]; then
   echo "proxy.pac file not available"
   exit 1
fi

if [ "$(wget --quiet --tries=1 --spider "http://${HOSTNAME}:81/wpad.dat"; echo $?)" -ne 0 ]; then
   echo "wpad.dat file not available"
   exit 1
fi

echo "proxy.pac and wpad.dat files available"
exit 0