#!/bin/bash

TIMESTAMP_FORMAT='%a %b %d %T %Y'
log() {
  echo "$(date +"${TIMESTAMP_FORMAT}") [tunnel-up] $*"
}

# If deluge-pre-stop.sh exists, run it
if [[ -x /config/deluge-pre-stop.sh ]]
then
   echo "Executing /config/deluge-pre-stop.sh"
   /config/deluge-pre-stop.sh "$@"
   echo "/config/deluge-pre-stop.sh returned $?"
fi

echo "Sending kill signal to deluge-daemon"
PID=$(pidof deluged)
kill $PID
# Give deluge-daemon time to shut down
for i in {1..10}; do
    ps -p $PID &> /dev/null || break
    sleep .2
done

# If deluge-post-stop.sh exists, run it
if [[ -x /config/deluge-post-stop.sh ]]
then
   echo "Executing /config/deluge-post-stop.sh"
   /config/deluge-post-stop.sh "$@"
   echo "/config/deluge-post-stop.sh returned $?"
fi
