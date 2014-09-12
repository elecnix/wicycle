#!/bin/sh

CheckNetwork()
{
  logger wicycle: Checking network...
  net=$(ping 8.8.8.8 -c5 | grep "time=")
  if [ "$net" ]; then
    logger wicycle: Network check passed.
    return 0
  else
    logger wicycle: Network check failed.
    return 1
  fi
}

ScanNetworks()
{
  logger wicycle: Performing network scan...
  scanres=
  ifconfig wlan0 down
  iw phy phy0 interface add scan0 type station
  ifconfig scan0 up
  while [ "$scanres" = "" ]; do
    scanres=$(iw scan0 scan)
  done
  iw dev scan0 del
  echo "$scanres"
}

Connect()
{
  ssid=$1
  channel=$2
  encryption=$3
  key=$4
  ifconfig wlan0 up
  killall -HUP hostapd
  logger wicycle: Attempting connection to $ssid on channel $channel
  uci set wireless.@wifi-iface[0].ssid="$ssid"
  uci set wireless.@wifi-iface[0].encryption="$encrypt"
  uci set wireless.@wifi-iface[0].key="$key"
  uci commit wireless
  /etc/init.d/network restart
}

ScanAndConnect()
{
  scanres=`ScanNetworks`
  for ssid in $scanres ; do
    active=$(echo $scanres | grep " $ssid ">&1 )
    if [ "$active" ]; then
      logger wicycle: Found "$ssid" network.
      Connect $ssid 1
      sleep 5
      CheckNetwork && return 0
    fi
  done
}

if [ "$1" = "--check" ]; then
  CheckNetwork
elif [ "$1" = "--scan" ]; then
  ScanNetworks
else  
  while [ "1" ]; do
    sleep 10
    CheckNetwork || ScanAndConnect
  done
fi

