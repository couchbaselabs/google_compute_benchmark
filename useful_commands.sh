#GCE Benchmark Useful Commands:

# Initialise Cluster
./clusterInit.sh charlie 45000  cb-server-1.c.cb-googbench-101.internal  cb-server-2.c.cb-googbench-101.internal  cb-server-3.c.cb-googbench-101.internal  cb-server-4.c.cb-googbench-101.internal  cb-server-5.c.cb-googbench-101.internal  cb-server-6.c.cb-googbench-101.internal  cb-server-7.c.cb-googbench-101.internal  cb-server-8.c.cb-googbench-101.internal  cb-server-9.c.cb-googbench-101.internal  cb-server-10.c.cb-googbench-101.internal

# Create RAM disks for all nodes
for i in `seq 1 10`; do gssh cb-server-$i --command "sudo su -c '/etc/init.d/couchbase-server stop; umount /opt/couchbase/var/lib/couchbase/data; mount -t tmpfs -o size=30720m tmpfs /opt/couchbase/var/lib/couchbase/data; /etc/init.d/couchbase-server start'"; done

# Flush charlie
curl -X POST localhost:8091/pools/default/buckets/charlie/controller/doFlush -u Administrator:password

# Increase disk cap
for i in `seq 1 10`; do ./cbepctl cb-server-$i:11210 -b charlie set tap_param tap_throttle_queue_cap 5000000; done

# Change front-end thread count
for i in `seq 1 10`; do curl --data 'ns_config:set({node, node(), {memcached, extra_args}}, ["-t16"]).' -u Administrator:password http://cb-server-$i:8091/diag/eval; done

# Reasonably ordinary pillowfight invocation
time -p cbc-pillowfight  -m 256 -M 256 -t 64 -I 10000000 -r 100 -U couchbase://cb-server-1/charlie -B 300

# Count memcached Threads
ps -L $(pgrep memcached) | grep -c memcached

# SSH locally
eval `ssh-agent`; ssh-add ~/.ssh/google_compute_engine; gssh --ssh-flag="-A" cb-server-2

# Process output.
for f in *.out; do echo $f; stats_report.py $f; done; mv *.png png; mv *.svg svg; mv *.out data

# Install 3.0.2
for i in `seq 1 10`; do gssh cb-server-$i --command "sudo su -c 'dpkg -r couchbase-server; wget http://packages.couchbase.com/releases/3.0.2/couchbase-server-enterprise_3.0.2-ubuntu12.04_amd64.deb; dpkg -i couchbase-server-enterprise_3.0.2-ubuntu12.04_amd64.deb'"; done 

# Install 2.5.2
for i in `seq 1 10`; do gssh cb-server-$i --command "sudo su -c 'dpkg -r couchbase-server; wget http://packages.couchbase.com.s3.amazonaws.com/releases/2.5.2/couchbase-server-enterprise_2.5.2_x86_64.deb; dpkg -i couchbase-server-enterprise_2.5.2_x86_64.deb'"; done 

# Compact a bucket
curl -X POST localhost:8091/pools/default/buckets/charlie/controller/compactBucket -u Administrator:password

# ht_locks
wget -O- --user=Administrator --password=password --post-data='ns_bucket:update_bucket_props("default", [{extra_config_string, “ht_locks=5"}]).' http://localhost:8091/diag/eval


#Create the bucket
couchbase-cli bucket-create -c localhost:8091 --user=Administrator --password=password --bucket=charlie --bucket-ramsize=24000 --bucket-replica=1 --bucket-type=couchbase

#tidy up after couch_create
parallel-ssh -h ./hosts "sudo sh -c 'find /opt/couchbase/var/lib/couchbase/data/charlie -user root -exec rm -fr {} \;'"

# Mount /dev/sdb on all nodes
for i in `seq 3 80`; do ssh  -o CheckHostIP=no -o StrictHostKeyChecking=no cb-server-$i "sudo su -c '/etc/init.d/couchbase-server stop; /usr/share/google/safe_format_and_mount -m \"mkfs.ext4 -F\" /dev/sdb /opt/couchbase/var/lib/couchbase/data; chown -R couchbase:couchbase /opt/couchbase/var/lib/couchbase/data; /etc/init.d/couchbase-server start'"; done


