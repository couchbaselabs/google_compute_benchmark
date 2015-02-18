#!/bin/bash


STATS="cmd_set ep_diskqueue_drain ep_diskqueue_fill vb_active_ops_create vb_replica_ops_create vb_active_ops_update vb_replica_ops_update ep_queue_size ep_flusher_todo vb_active_queue_fill vb_replica_queue_fill vb_active_queue_drain vb_replica_queue_drain cpu_utilization_rate curr_items ep_dcp_replica_items_remaining ep_dcp_replica_items_sent"

2.X_STATS="ep_tap_replica_queue_backoff ep_tap_replica_queue_backfillremaining"

while [ 1 ]
do
  for stat in $STATS
  do
    echo "Collecting $stat"
    curl -s "http://localhost:8091/pools/default/buckets/charlie/stats/${stat}?zoom=minute" >> /tmp/${stat}.out
    echo >> /tmp/${stat}.out
  done
  echo Sleeping
  sleep 55
done
