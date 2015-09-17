#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source ${DIR}/settings

function controlInstances {
for i in $(seq 1 $2)
do
    INSTANCE="${3}-${i}"
    gcloud compute --project $PROJECT instances $1 $INSTANCE --zone $ZONE --quiet &
done
}

# MAIN
case "$1" in
        start)
            echo -n "Starting..."
            CONTROL_COMMAND="start"
            ;;

        stop)
            echo -n "Stopping..."
            CONTROL_COMMAND="stop"
            ;;

        reset)
            echo -n "Resetting..."
            CONTROL_COMMAND="reset"
            ;;

        *)
            echo $"Usage: $0 {stop|start|reset}"
            exit 1

esac

case "$2" in
        servers)
            echo "Couchbase servers."
            CONTROL_SERVERS=1
            ;;

        clients)
            echo "Couchbase clients."
            CONTROL_CLIENTS=1
            ;;

        *)
            echo "Couchbase clients and servers."
            CONTROL_SERVERS=1
            CONTROL_CLIENTS=1
            ;;

esac

if [ -n "$CONTROL_SERVERS" ]; then controlInstances $CONTROL_COMMAND $NUM_SERVERS $NODE_PREFIX; fi
if [ -n "$CONTROL_CLIENTS" ]; then controlInstances $CONTROL_COMMAND $NUM_CLIENTS $NODE_CLIENT_PREFIX; fi
