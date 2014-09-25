#!/bin/sh

HOME_HOSTNAME=${HOME_HOSTNAME:-destination.host}
HOME_PORT=${HOME_PORT:-2413}
LOG_BASEDIR=${LOG_BASEDIR:-/tmp/wicycle/log}
HOME_BASEURL=http://$HOME_HOSTNAME:$HOME_PORT

CheckNetwork()
{
  logger wicycle: Checking network...
  net=$(ping 8.8.8.8 -c5 2>/dev/null | grep "time=")
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
  iw phy phy0 interface add scan0 type station || return 1
  ifconfig scan0 up || return 2
  while [ "$scanres" = "" ]; do
    NOW=$(date -Iseconds)
    scanres=$(iw scan0 scan | tee /tmp/wicycle.scan)
  done
  iw dev scan0 del

  # Log
  mkdir -p $LOG_BASEDIR
  bssid_list=$(cat /tmp/wicycle.scan | grep ^BSS | sed -e 's/BSS \(.*\)(.*/\1/' | sort | uniq)
  for bssid in $bssid_list ; do
    echo $NOW >> $LOG_BASEDIR/$bssid
  done
  count=$(echo "$bssid_list" | wc -l)
  logger wicycle Logged $count networks
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
  cat /tmp/wicycle.scan | sed -e 's#(on # (on #g' | awk -f /bin/wicycle.awk > /tmp/wicycle.scan.sh
  . /tmp/wicycle.scan.sh
  logger wicycle NETWORK_COUNT=$NETWORK_COUNT
  net=0
  while [ $net != $NETWORK_COUNT ] ; do
    net=$(expr $net + 1)
    for prefix in BSS SSID CHANNEL ENCRYPTION ; do
      varname="${prefix}_${net}"
      logger wicycle $net $prefix "$(eval echo \$$varname)" 
#    if [ "$open" ]; then
#      Connect $ssid 1 none
#      sleep 5
#      CheckNetwork && return 0
#    fi
    done
  done
  # TODO
  exit 1
}

SendLog()
{
  [ -r $LOG_BASEDIR ] || return 1
  for bssid in `ls $LOG_BASEDIR` ; do
    file=$LOG_BASEDIR/$bssid
    echo "Sending $file"
    echo $'POST /log/'`echo $bssid`$' HTTP/1.1\r\nUser-Agent:wicycle/0.1\r\nContent-type: application/x-www-form-urlencoded\r\nContent-length: '`wc -c < $file`$'\r\nConnection: Close\r\n\r\n'`cat $file` | nc $HOME_HOSTNAME $HOME_PORT
  done
}

MainLoop()
{
  while [ "1" ]; do
    ( CheckNetwork || ScanAndConnect ) && SendLog
    sleep 30
  done
}

if [ "$1" = "--check" ]; then
  CheckNetwork
elif [ "$1" = "--scan" ]; then
  ScanNetworks
elif [ "$1" = "--reconnect" ]; then
  ScanAndConnect
elif [ "$1" = "--send" ]; then
  SendLog
elif [ "$1" = "--daemon" ]; then
  MainLoop &
  echo "$!" > /var/run/wicycle.pid             
else
  MainLoop
fi

