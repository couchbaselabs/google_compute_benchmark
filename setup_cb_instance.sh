#! /bin/bash
mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb
mkdir -p /opt/couchbase/var/lib/couchbase/data
mount -o discard,defaults /dev/sdb  /opt/couchbase/var/lib/couchbase/data
chown -R couchbase:couchbase /opt/couchbase/var/lib/couchbase/data
/etc/init.d/couchbase-server restart
