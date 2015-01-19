#! /bin/bash

# Create Client Snapshot
rm -f /tmp/ready

apt-get -qq install default-jre
wget http://support.couchbase.com.s3.amazonaws.com/RoadRunner-0.3-jar-with-dependencies.jar

wget http://packages.couchbase.com/clients/c/couchbase-csdk-setup
yes | perl couchbase-csdk-setup
apt-get -qq install python-dev python-pip
pip install couchbase

touch /tmp/ready
