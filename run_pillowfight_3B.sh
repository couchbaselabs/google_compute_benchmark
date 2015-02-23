#!/bin/bash

set -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source ${DIR}/gcloud_inc.sh

CLIENT="cb-client"
#NUM_DOCS=$(( 100 * 1000000 ))
NUM_DOCS=$(( 3000 * 1000000 ))
#WORKING_SET=$(( 100 * 1000000 ))
WORKING_SET=${NUM_DOCS}
PHYSICAL_CLIENTS=32
NUM_CLIENTS=32
BATCH_SIZE=10
TOKENS=--tokens=150
#ITERATIONS=$(( $(( ${WORKING_SET} / ${BATCH_SIZE} / ${NUM_CLIENTS} )) + 1 ))
ITERATIONS=$(( $(( ${WORKING_SET} / ${NUM_CLIENTS} )) ))
#ITERATIONS=100
DOCS_PER_CLIENT=$(( ${WORKING_SET} / ${NUM_CLIENTS} ))
RATE_LIMIT=0
THREADS=4

PILLOWFIGHT="ulimit -n 10240 && ./cbc-pillowfight --min-size=200 --max-size=200 \
  --num-threads=${THREADS} --num-items=${DOCS_PER_CLIENT} --set-pct=100 \
  --spec=couchbase://cb-server-1/charlie --batch-size=${BATCH_SIZE} --num-cycles=${ITERATIONS} \
  --sequential --no-population --rate-limit=${RATE_LIMIT} --durability ${TOKENS}"

echo "=== Running ${NUM_CLIENTS} clients ${THREADS} threads accessing ${WORKING_SET} documents (${ITERATIONS} iterations) ==="
echo

trap ctrl_c INT
function ctrl_c() {
    echo "** Caught Ctrl-C - terminating clients..."
    for i in $(seq 1 ${PHYSICAL_CLIENTS}); do
        gcloud_ssh ${CLIENT}-${i} "pgrep cbc-pillowfight | xargs kill"
    done
    exit
}

# Start monitoring
monitor_host=cb-server-4
gcloud compute --project ${PROJECT} copy-files --zone ${ZONE} cb_perf_monitor.sh ${monitor_host}:.
gcloud_ssh ${monitor_host} "chmod 0755 cb_perf_monitor.sh && ./cb_perf_monitor.sh" &
MONITOR_PID=$!

for i in $(seq 1 ${NUM_CLIENTS}); do
    host_num=$(( $i % ${PHYSICAL_CLIENTS} ))
    if [[ $host_num == "0" ]]; then
        host_num=${PHYSICAL_CLIENTS}
    fi
    host=${CLIENT}-${host_num}
    echo "* Starting client $i (host $host)"
    if [[ $i == "1" ]]; then
        # 1 is special; we record timings directly from it.
        echo "Client $i outputting to durability_perf.$$"
        gcloud_ssh ${host} "${PILLOWFIGHT} --key-prefix=c${i} > durability_perf.$$" &
        CLIENT_PID[${i}]=$!
    else
        # rest just discard output.
        gcloud_ssh ${host} "${PILLOWFIGHT} --key-prefix=c${i} > /dev/null" &
        CLIENT_PID[${i}]=$!
    fi
    # wait between each one
    sleep 2
done

for i in $(seq 1 ${NUM_CLIENTS}); do
    wait ${CLIENT_PID[$i]}
done

kill $MONITOR_PID
