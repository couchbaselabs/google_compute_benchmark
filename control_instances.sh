#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source ${DIR}/settings

function controlInstances {
for i in $(seq 1 $NUM_SERVERS)
do
    INSTANCE="${NODE_PREFIX}-${i}"
    gcloud compute --project $PROJECT instances $1 $INSTANCE --quiet &
done
}

# MAIN
case "$1" in
        start)
            echo "Starting..."
            controlInstances start
            ;;

        stop)
            echo "Stopping..."
            controlInstances stop
            ;;

        reset)
            echo "Resetting..."
            controlInstances reset
            ;;

        *)
            echo $"Usage: $0 {stop|start|reset}"
            exit 1

esac