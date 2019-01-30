#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source ${DIR}/settings



# Create Server snapshot
function createServerTemplate {

  echo "Creating Template for Couchbase Server Instances..."

  echo "Deleting previous master Couchbase Server instance"
  gcloud compute --project $PROJECT instances delete $BASE_IMAGE_NAME --zone $ZONE --quiet

  echo "Creating master Couchbase Server instance..."
  gcloud compute --project $PROJECT instances create $BASE_IMAGE_NAME --zone $ZONE --machine-type ${SERVER_TYPE} --network "default" --maintenance-policy "MIGRATE" --scopes "https://www.googleapis.com/auth/devstorage.read_only" --tags "http-server,https-server" --image-family $IMAGE_FAMILY --boot-disk-type "pd-standard" --boot-disk-device-name $BASE_IMAGE_NAME --metadata-from-file startup-script=setup_cb_image.sh --image-project $IMAGE_PROJECT

  while [ "`gcloud compute instances describe $BASE_IMAGE_NAME --project $PROJECT --zone $ZONE | grep  "status:" | cut -d' ' -f2`" != "TERMINATED" ]; do
    echo "Waiting for server startup script to finish"
    sleep 10
  done

  echo "Taking snapshot of root volumes..."
  gcloud compute --project $PROJECT disks snapshot "https://www.googleapis.com/compute/v1/projects/${PROJECT}/zones/${ZONE}/disks/${BASE_IMAGE_NAME}" --zone $ZONE --snapshot-names $SERVER_SNAPSHOT

  echo "Deleting template instance"
  gcloud compute --project $PROJECT instances delete $BASE_IMAGE_NAME --zone $ZONE --quiet

}

function createClientTemplate {

  echo "Creating Template for Couchbase Client Instances..."

  gcloud compute --project $PROJECT instances create $CLIENT_SNAPSHOT --zone $ZONE --machine-type ${CLIENT_TYPE} --network "default" --maintenance-policy "MIGRATE" --scopes "https://www.googleapis.com/auth/devstorage.read_only" --tags "http-server,https-server" --image-family $IMAGE_FAMILY --boot-disk-type "pd-standard" --boot-disk-device-name $CLIENT_SNAPSHOT --metadata-from-file startup-script=setup_client_image.sh  --image-project $IMAGE_PROJECT

  rm -f /tmp/client-ready
  while [ ! -f /tmp/client-ready ]; do
    echo "Waiting for client startup script to finish"
    gcloud compute copy-files -q --project $PROJECT --zone $ZONE $CLIENT_SNAPSHOT:/tmp/ready /tmp/client-ready
    sleep 10
  done

  echo "Taking snapshot of root volumes..."
  gcloud compute --project $PROJECT disks snapshot "https://www.googleapis.com/compute/v1/projects/${PROJECT}/zones/${ZONE}/disks/${CLIENT_SNAPSHOT}" --zone $ZONE --snapshot-names $CLIENT_SNAPSHOT

  echo "Deleting template instance"
  gcloud compute --project $PROJECT instances delete $CLIENT_SNAPSHOT --zone $ZONE --quiet

}

# create a single instance
function createServerInstance {
  INSTANCE=$1
  NETWORK_SETTING=$2

  gcloud compute --project $PROJECT instances stop $INSTANCE --quiet --zone $ZONE
  if ! gcloud compute --project $PROJECT instances delete $INSTANCE --zone $ZONE --delete-disks all --quiet; then
    gcloud compute --project $PROJECT disks delete ${INSTANCE}-boot --zone $ZONE --quiet
  fi
  gcloud compute --project $PROJECT disks delete ${INSTANCE}-data --zone $ZONE --quiet

  gcloud compute --project $PROJECT disks create ${INSTANCE}-boot --zone $ZONE --source-snapshot $SERVER_SNAPSHOT --type "pd-standard"
  gcloud compute --project $PROJECT disks create ${INSTANCE}-data --zone $ZONE --size $DATA_DISK_SIZE --type $DATA_DISK_TYPE
  gcloud compute --project $PROJECT instances create $INSTANCE --zone $ZONE --machine-type ${SERVER_TYPE} ${NETWORK_SETTING} --maintenance-policy "MIGRATE" --scopes "https://www.googleapis.com/auth/devstorage.read_only" --tags "http-server,https-server" --disk "name=${INSTANCE}-boot,device-name=${INSTANCE}-boot,mode=rw,boot=yes,auto-delete=yes" --disk "name=${INSTANCE}-data,device-name=${INSTANCE}-data,mode=rw,boot=no"  --metadata-from-file startup-script=setup_cb_instance.sh
}

# batch create
function createServerInstances {
# Create server instances
PER_BATCH=$INSTANCE_CREATE_BATCH_SIZE
for i in $(seq 1 ${PER_BATCH} $NUM_SERVERS)
do
  BATCH_START=$i
  BATCH_END=$(expr $i + $(expr $PER_BATCH - 1))
  if [[ $BATCH_END -gt $NUM_SERVERS ]]; then
    BATCH_END=$NUM_SERVERS
  fi
  for instance in $(seq ${BATCH_START} ${BATCH_END})
  do
    INSTANCE="${NODE_PREFIX}-${instance}"
    # Only assign external IP addresses to the first few nodes (we
    # only have a limited number available).
    if [[ $instance -le 7 ]]; then
      NETWORK_SETTINGS="--network default"
    else
      NETWORK_SETTINGS="--network default --no-address"
    fi
    echo "=== Creating $INSTANCE ==="
    createServerInstance $INSTANCE "$NETWORK_SETTINGS" &
    WAITPID=$!
  done
    echo "Waiting for creation of instances"
    wait $WAITPID
done
}


function createClientInstances {
# Create Client instances
for i in `seq 1 $NUM_CLIENTS`
do
  INSTANCE="${NODE_CLIENT_PREFIX}-${i}"
  echo Creating $INSTANCE
  gcloud compute --project $PROJECT disks create ${INSTANCE}-boot --zone $ZONE --source-snapshot $CLIENT_SNAPSHOT --type "pd-standard"
  gcloud compute --project $PROJECT instances create $INSTANCE --zone $ZONE --machine-type ${CLIENT_TYPE} --network "default" --no-address --maintenance-policy "MIGRATE" --scopes "https://www.googleapis.com/auth/devstorage.read_only" --disk "name=${INSTANCE}-boot" "device-name=${INSTANCE}-boot" "mode=rw" "boot=yes" "auto-delete=yes"
done
}

# MAIN
case "$1" in
        create-server-template)
            echo "Creating Server Template"
            createServerTemplate
            ;;

        create-client-template)
            echo "Creating Client Template"
            createClientTemplate
            ;;

        create-server-instances)
            echo "Creating Server Instances"
            createServerInstances
            ;;

        create-client-instances)
            echo "Creating Client Instances"
            createClientInstances
            ;;
        *)
            echo $"Usage: $0 {create-server-template|create-client-template|create-server-instances|create-client-instances}"
            exit 1

esac
