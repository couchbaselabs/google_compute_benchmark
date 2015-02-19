#!/bin/bash

PROJECT="cb-googbench-101"
ZONE="us-central1-f"
CLIENT="cb-client"
NUM_DOCS=$(( 100 * 1000000 ))
#NUM_DOCS=$(( 3 * 1000 * 1000000 ))
PHYSICAL_CLIENTS=16
NUM_CLIENTS=16
BATCH_SIZE=200
ITERATIONS=$(( $(( NUM_DOCS / BATCH_SIZE / NUM_CLIENTS )) + 1 ))
#ITERATIONS=5000
DOCS_PER_CLIENT=$(( ${NUM_DOCS} / ${NUM_CLIENTS} ))
RATE_LIMIT=5000
THREADS=16

PILLOWFIGHT="ulimit -n 10240 && ./cbc-pillowfight --min-size=200 --max-size=200 \
  --num-threads=${THREADS} --num-items=${DOCS_PER_CLIENT} --set-pct=100 \
  --spec=couchbase://cb-server-1/charlie --batch-size=${BATCH_SIZE} --num-cycles=${ITERATIONS} \
  --sequential --no-population --rate-limit=${RATE_LIMIT}  --durability"


echo "=== Running ${NUM_CLIENTS} clients ${THREADS} threads accessing ${NUM_DOCS} documents (${ITERATIONS} iterations) ==="
echo

trap ctrl_c INT
function ctrl_c() {
    echo "** Caught Ctrl-C - terminating clients..."
    for i in $(seq 1 ${PHYSICAL_CLIENTS}); do
        gcloud compute --project ${PROJECT} ssh --zone ${ZONE} ${CLIENT}-${i} \
               --command "kill \$(pgrep cbc-pillowfight)"
    done
    exit
}

for i in $(seq 1 ${NUM_CLIENTS}); do
    echo "* Starting client $i"
    host=${CLIENT}-$(( $(( $i % ${PHYSICAL_CLIENTS} )) + 1 ))
    if [[ $i == "1" ]]; then
        # 1 is special; we record timings directly from it.
        echo "Client $i outputting to durability_perf.$$"
        gcloud compute --project ${PROJECT} ssh --zone ${ZONE} ${host} \
                  --command "${PILLOWFIGHT} --key-prefix=c${i} > durability_perf.$$" &
    else
        # rest just discard output.
           gcloud compute --project ${PROJECT} ssh --zone ${ZONE} ${host} \
                  --command "${PILLOWFIGHT} --key-prefix=c${i} > /dev/null" &
        true
    fi
    # wait between each one
    sleep 1
done
wait
