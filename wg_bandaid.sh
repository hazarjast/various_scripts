#!/bin/sh

LOGFILE=/var/log/wg_bandaid.log
PIDFILE=/var/run/wg_bandaid.pid
TUNNAME=wg0
TUNCONF=/usr/local/etc/wireguard/$TUNNAME.conf
STRPCNF=/tmp/$TUNNAME.conf
OPNSNSE=$(which wg-quick)

# Preliminary logic to ensure this only runs one instance at a time
if [ -f $PIDFILE ]
then
  PID=$(cat $PIDFILE)
  ps -p $PID > /dev/null 2>&1
  if [ $? -eq 0 ]
  then
    echo "$(date) - Process already running. Exiting." >> $LOGFILE
    exit 1
  else
    echo $$ > $PIDFILE
    if [ $? -ne 0 ]
    then
      echo "$(date) - Could not create PID file. Exiting." >> $LOGFILE
      exit 1
    fi
  fi
else
  echo $$ > $PIDFILE
  if [ $? -ne 0 ]
  then
    echo "$(date) - Could not create PID file. Exiting." >> $LOGFILE
    exit 1
  fi
fi

# Check if running OPNSense and cleanup tunnel config file if so
[ ! -z $OPNSNSE ] && wg-quick strip $TUNCONF > $STRPCNF && TUNCONF=$STRPCNF

# Main command
[ $(( $(date +%s) - $(wg show $TUNNAME latest-handshakes | awk '{print $2}') )) -gt 300 ] && \
wg set $TUNNAME listen-port 51$(jot -r 1 100 999) && sleep 300 && \
wg syncconf $TUNNAME $TUNCONF && \
echo "$(date) - Had to jiggle $TUNNAME listen-port to fix handshaking!" >> $LOGFILE

# Cleanup after ourselves
[ -f $STRPCNF ] && rm $STRPCNF
rm $PIDFILE

# Keep log from getting too large
if [ -f $LOGFILE ]
then
  echo "$(tail -1000 $LOGFILE)" > $LOGFILE
fi

exit 0
