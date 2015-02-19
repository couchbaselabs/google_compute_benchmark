#!/bin/bash

PROJECT="cb-googbench-101"
ZONE="us-central1-f"
NUM_SERVERS=20
NUM_CLIENTS=16
SERVER_SNAPSHOT="couchbase-3-0-2"
BASE_IMAGE_NAME="cb-server-template"
CLIENT_SNAPSHOT='cb-client-image'
CB_DATA_DISK="cb-data-disk"
CB_DATA_SNAPSHOT="cb-data-snapshot"
DATA_DISK_TYPE="pd-ssd"  # "pd-standard" or "pd-ssd"
DATA_DISK_SIZE=500

# Create Server snapshot

function createServerTemplate {

  echo "Creating Template for Couchbase Server Instances..."

  echo "Deleting previous data volume..."
  gcloud compute --project $PROJECT disks delete ${CB_DATA_DISK}-${DATA_DISK_SIZE} --zone $ZONE --quiet

  echo "Deleting previous master Couchbase Server instance"
  gcloud compute --project $PROJECT instances delete $BASE_IMAGE_NAME --zone $ZONE --quiet

  echo "Creating blank data volume..."
  gcloud compute --project $PROJECT disks create ${CB_DATA_DISK}-${DATA_DISK_SIZE} --size $DATA_DISK_SIZE --zone $ZONE --type "pd-standard"

  echo "Creating master Couchbase Server instance..."
  gcloud compute --project $PROJECT instances create $BASE_IMAGE_NAME --zone $ZONE --machine-type "n1-standard-1" --network "default" --maintenance-policy "MIGRATE" --scopes "https://www.googleapis.com/auth/devstorage.read_only" --tags "http-server" "https-server" --image "https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/backports-debian-7-wheezy-v20150112" --boot-disk-type "pd-standard" --boot-disk-device-name $BASE_IMAGE_NAME  --disk "name=${CB_DATA_DISK}-${DATA_DISK_SIZE}" "device-name=${CB_DATA_DISK}-${DATA_DISK_SIZE}" "mode=rw" "boot=no" --metadata-from-file startup-script=setup_cb_image.sh

  while [ "`gcloud compute instances describe $BASE_IMAGE_NAME --project $PROJECT --zone $ZONE | grep  "status:" | cut -d' ' -f2`" != "TERMINATED" ]; do
    echo "Waiting for server startup script to finish"
    sleep 10
  done

  echo "Taking snapshot of root and data volumes..."
  gcloud compute --project $PROJECT disks snapshot "https://www.googleapis.com/compute/v1/projects/${PROJECT}/zones/${ZONE}/disks/${BASE_IMAGE_NAME}" --zone $ZONE --snapshot-names $SERVER_SNAPSHOT
  gcloud compute --project $PROJECT disks snapshot "https://www.googleapis.com/compute/v1/projects/${PROJECT}/zones/${ZONE}/disks/${CB_DATA_DISK}-${DATA_DISK_SIZE}" --zone $ZONE --snapshot-names ${CB_DATA_SNAPSHOT}-${DATA_DISK_SIZE}
}

function createClientTemplate {

  echo "Creating Template for Couchbase Client Instances..."

  gcloud compute --project $PROJECT instances create $CLIENT_SNAPSHOT --zone $ZONE --machine-type "n1-standard-1" --network "default" --maintenance-policy "MIGRATE" --scopes "https://www.googleapis.com/auth/devstorage.read_only" --tags "http-server" "https-server" --image "https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/backports-debian-7-wheezy-v20150112" --boot-disk-type "pd-standard" --boot-disk-device-name $CLIENT_SNAPSHOT  --metadata-from-file startup-script=setup_client_image.sh

rm -f /tmp/client-ready
while [ ! -f /tmp/client-ready ]; do
  echo "Waiting for client startup script to finish"
  gcloud compute copy-files -q --project $PROJECT --zone $ZONE $CLIENT_SNAPSHOT:/tmp/ready /tmp/client-ready
  sleep 10
done

gcloud compute --project $PROJECT disks snapshot "https://www.googleapis.com/compute/v1/projects/${PROJECT}/zones/${ZONE}/disks/${CLIENT_SNAPSHOT}" --zone $ZONE --snapshot-names $CLIENT_SNAPSHOT

}

function createServerInstances {
# Create server instances
for i in `seq 1 $NUM_SERVERS`
do
  INSTANCE="cb-server-$i"
  echo Creating $INSTANCE
  gcloud compute --project $PROJECT  disks create ${INSTANCE}-boot --zone $ZONE --source-snapshot $SERVER_SNAPSHOT --type "pd-standard"
  gcloud compute --project $PROJECT  disks create ${INSTANCE}-data --zone $ZONE --source-snapshot ${CB_DATA_SNAPSHOT}-${DATA_DISK_SIZE} --type $DATA_DISK_TYPE

  gcloud compute --project $PROJECT instances create $INSTANCE --zone $ZONE --machine-type "n1-standard-16" --network "default" --maintenance-policy "MIGRATE" --scopes "https://www.googleapis.com/auth/devstorage.read_only" --tags "http-server" "https-server" --disk "name=${INSTANCE}-boot" "device-name=${INSTANCE}-boot" "mode=rw" "boot=yes" "auto-delete=yes" --disk "name=${INSTANCE}-data" "device-name=${INSTANCE}-data" "mode=rw" "boot=no"
done
}


function createClientInstances {
# Create Client instances
for i in `seq 1 $NUM_CLIENTS`
do
  INSTANCE="cb-client-$i"
  echo Creating $INSTANCE
  gcloud compute --project $PROJECT disks create ${INSTANCE}-boot --zone $ZONE --source-snapshot $CLIENT_SNAPSHOT --type "pd-standard"
  gcloud compute --project $PROJECT instances create $INSTANCE --zone $ZONE --machine-type "n1-highcpu-16" --network "default" --maintenance-policy "MIGRATE" --scopes "https://www.googleapis.com/auth/devstorage.read_only" --tags "http-server" "https-server" --disk "name=${INSTANCE}-boot" "device-name=${INSTANCE}-boot" "mode=rw" "boot=yes" "auto-delete=yes"
done
}


# MAIN
#createServerTemplate
#createClientTemplate
createServerInstances
#createClientInstances
