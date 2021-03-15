#!/bin/bash

TIMESTAMP_FORMAT='%a %b %d %T %Y'
log() {
  echo "$(date +"${TIMESTAMP_FORMAT}") [deluge-stop] $*"
}

# If deluge-pre-stop.sh exists, run it
if [[ -x /config/deluge-pre-stop.sh ]]
then
   log "Executing /config/deluge-pre-stop.sh"
   /config/deluge-pre-stop.sh "$@"
   log "/config/deluge-pre-stop.sh returned $?"
fi

log "Sending kill signal to deluge-daemon"
PID=$(pidof deluged)
kill -9 $PID
# Give deluge-daemon time to shut down
for i in {1..10}; do
    ps -p $PID &> /dev/null || break
    sleep .2
done

# If deluge-post-stop.sh exists, run it
if [[ -x /config/deluge-post-stop.sh ]]
then
   log "Executing /config/deluge-post-stop.sh"
   /config/deluge-post-stop.sh "$@"
   log "/config/deluge-post-stop.sh returned $?"
fi
