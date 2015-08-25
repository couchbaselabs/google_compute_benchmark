# Couchbase Google Compute Benchmarking

## Welcome!
This repo contains scripts that will allow you to do the following:
* Create Couchbase Server and Couchbase Client instances in GCE
* Initialise the Couchbase cluster
* Install our benchmarking load-generator on a number of clients
* Invoke the load generator and record some stats
* Post-process these stats ready for analysis

## Pre-requisites
These scripts assume you already have access to GCE, have gcloud installed and are authenticated to a particular project. The scripts source
the "settings" file for all the configuration of GCE and Couchbase.
If you want to use the Couchbase UI externally, you'll also want your project's network settings to allow access to port 8091.

## Creating your instances
First you'll want to create some instances. This is performed by the `create_instances` script.

There are 4 stages to this:

1. Create the Server template `./create_instances.sh create-server-template`
2. Create the Client template `./create_instances.sh create-client-template`
3. Create Server instances based on the template `./create_instances.sh create-server-instances`
  * Instances are created in parallel-batches so the output can get garbled.
4. Create Client instances based on the template `./create_instances.sh create-client-instances`

The Server and Client templates are customised by the `setup_cb_image`, `setup_cb_instance` and `setup_client_image` scripts respectively.

## Initialising the Couchbase Cluster
This is done by `clusterInit` script and there are two stages.

1. Cluster init
2. Bucket creation

For both steps you will need the external address of one of the couchbase nodes and the couchbase-cli in your PATH.

### Cluster Init
The parameters are `external-address` and `cluster-quota-MB`.
```
# 50GB cluster
./clusterInit.sh create-cluster 104.154.61.11 50000
```

### Bucket Create
*This step can be repeated to add more buckets.*

The parameters are `external-address`, `bucket-name` and `bucket-quota-MB`
```
1GB bucket called charlie
./clusterInit.sh create-bucket 104.154.61.11 charlie 1000
```

## Installing the Load Generator
Next you want to install our load generator (libcouchbase's "pillowfight") on each of the client instances. This is done by `build_install_pillowfight`.

## Generating Some Load
Now it's time to run some load - do this by running `run_pillowfight_3B`. Again note the variables at the top that dictate how many clients, how many documents in the dataset etc.
Log on to the Couchbase UI (<cb-server-node-external-IP: 8091

## Capturing the output
The load generator selects a machine and runs the `cb_perf_monitor` script on it. This creates a series of .out files on that Server node's `/tmp` directory. These should be copied locally for further post-processing and analysis. The first client instance also produces a "durability_perf.<pid>" file which captures the latency timings for the operations.

## Post-processing the stats
`stats_report.py` takes the .out files generated above and converts them to several SVG files, using pygal.
