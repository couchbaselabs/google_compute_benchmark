#!/bin/bash

# Example script to automate cluster initialisation, add hosts and create buckets
# For illustration purposes only - paths, arguments and return values should be checked for errors


#
# Make sure couchbase-cli is in the path (Linux / Mac)
#
if [ `uname` == "Darwin" ]
then
export PATH=$PATH:/Applications/Couchbase\ Server.app/Contents/Resources/couchbase-core/bin/
else
    export PATH=$PATH:/opt/couchbase/bin/
fi

if [ "$#" -lt 4 ]
then
    echo "Usage $0: <bucketname> <size> <host1....>"
    exit
fi


# Parameters for bucket one (couchbase-type)
BUCKET_NAME=$1
BUCKET_TYPE=couchbase  # memcached
BUCKET_QUOTA=$2
BUCKET_REPLICA=1
PORT=8091
USER=Administrator
PASS=password
CLUSTER_MEM=50000
CBPATH=/opt/couchbase/var/lib/couchbase/data

HOST1=$3


#
# (Optional) set the path to be used to store both the data and indexes.
#
couchbase-cli node-init -c $HOST1 --node-init-data-path=$CBPATH --node-init-index-path=$CBPATH -u $USER -p $PASS

#
# Initialise the cluster with a single node, using the credentials specified above
#
couchbase-cli cluster-init -c $HOST1 \
        -u $USER \
        -p $PASS \
       --cluster-init-port=$PORT \
       --cluster-init-ramsize=$CLUSTER_MEM

#       --cluster-init-username=$USER \ # 2.x
#       --cluster-init-password=$PASS \ # 2.x

#
# Add all remaining nodes to the cluster
# This command can be copied (or used in a loop) for multiple hosts
# Start with the 4th param because cluster has been initialised with the first node

for NODE in ${@:4}
do
echo Adding $NODE to the cluster
couchbase-cli server-add -c ${HOST1}:${PORT} \
				--user=${USER} \
				--password=${PASS} \
       --server-add=${NODE}:${PORT} \
       --server-add-username=${USER} \
       --server-add-password=${PASS}

done
#
# A rebalance is necessary to ensure all nodes added above are fully introduced to the
# cluster. This is best performed before adding buckets
#
couchbase-cli rebalance -c ${HOST1}:${PORT} --user=${USER} --password=${PASS}


#
# Create a couchbase-type bucket using the credentials supplied above
#
couchbase-cli bucket-create -c ${HOST1}:${PORT} \
				--user=${USER} \
				--password=${PASS} \
                --bucket=${BUCKET_NAME} \
                --bucket-ramsize=${BUCKET_QUOTA} \
                --bucket-replica=${BUCKET_REPLICA} \
                --bucket-type=${BUCKET_TYPE}
