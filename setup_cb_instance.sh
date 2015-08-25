#! /bin/bash
/usr/share/google/safe_format_and_mount -m "mkfs.ext4 -F" $(ls /dev/disk/by-id/google-*-data) /opt/couchbase/var/lib/couchbase/data/
chown -R couchbase:couchbase /opt/couchbase/var/lib/couchbase/data
/etc/init.d/couchbase-server restart