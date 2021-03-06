#!/usr/bin/env bash

# Setup env vars and folders for the ctl script
# This helps keep the ctl script as readable
# as possible

# Usage options:
# source /var/vcap/jobs/foobar/helpers/ctl_setup.sh JOB_NAME OUTPUT_LABEL
# source /var/vcap/jobs/foobar/helpers/ctl_setup.sh foobar
# source /var/vcap/jobs/foobar/helpers/ctl_setup.sh foobar foobar
# source /var/vcap/jobs/foobar/helpers/ctl_setup.sh foobar nginx

set -e # exit immediately if a simple command exits with a non-zero status
set -u # report the usage of uninitialized variables

JOB_NAME=$1
output_label=${2:-${JOB_NAME}}

export JOB_DIR=/var/vcap/jobs/$JOB_NAME
chmod 755 $JOB_DIR # to access file via symlink

# Load some bosh deployment properties into env vars
# Try to put all ERb into data/properties.sh.erb
# incl $NAME, $JOB_INDEX, $WEBAPP_DIR
source $JOB_DIR/data/properties.sh

source $JOB_DIR/helpers/ctl_utils.sh
redirect_output ${output_label}

export HOME=${HOME:-/home/vcap}

# Add all packages' /bin & /sbin into $PATH
for package_bin_dir in $(ls -d /var/vcap/packages/*/*bin)
do
  export PATH=${package_bin_dir}:$PATH
done

export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-''} # default to empty
for package_bin_dir in $(ls -d /var/vcap/packages/*/lib)
do
  export LD_LIBRARY_PATH=${package_bin_dir}:$LD_LIBRARY_PATH
done

# Setup log, run and tmp folders

export RUN_DIR=/var/vcap/sys/run/$JOB_NAME
export LOG_DIR=/var/vcap/sys/log/$JOB_NAME
export TMP_DIR=/var/vcap/sys/tmp/$JOB_NAME
export STORE_DIR=/var/vcap/store/$JOB_NAME
export BACKUP_DATA_DIR=/var/vcap/store/backups
export RESTORE_DATA_DIR=/var/vcap/store/restores
#export CQLSH_DIR=/var/vcap/store/cqlhist

for dir in $RUN_DIR $LOG_DIR $TMP_DIR $STORE_DIR $BACKUP_DATA_DIR $RESTORE_DATA_DIR 
do
  mkdir -p ${dir}
  chown vcap:vcap ${dir}
  chmod 775 ${dir}
done
export TMPDIR=$TMP_DIR

export C_INCLUDE_PATH=/var/vcap/packages/mysqlclient/include/mysql:/var/vcap/packages/sqlite/include:/var/vcap/packages/libpq/include
export LIBRARY_PATH=/var/vcap/packages/mysqlclient/lib/mysql:/var/vcap/packages/sqlite/lib:/var/vcap/packages/libpq/lib

#  pour test cqlsh history /root/.cassandra
chmod 777 /root
# consistent place for vendoring python libraries within package
if [[ -d ${WEBAPP_DIR:-/xxxx} ]]
then
  export PYTHONPATH=$WEBAPP_DIR/vendor/lib/python
fi

if [[ -d /var/vcap/packages/java7 ]]
then
  export JAVA_HOME="/var/vcap/packages/java7"
fi

# setup CLASSPATH for all jars/ folders within packages
export CLASSPATH=${CLASSPATH:-''} # default to empty
for java_jar in $(ls -d /var/vcap/packages/*/*/*.jar)
do
  export CLASSPATH=${java_jar}:$CLASSPATH
done

PIDFILE=$RUN_DIR/$output_label.pid

echo '$PATH' $PATH
/sbin/swapoff -a
echo 'verify swap deactivate : ' `swapon -s`

if [[ -d ${JOB_DIR}/tools/bin/graph ]]
then
 rm -rf $JOB_DIR/tools/bin/graph
fi
mkdir -p $JOB_DIR/tools/bin/graph
chmod 777 $JOB_DIR/tools/bin/graph
chmod +x  $JOB_DIR/tools/bin/cassandra-stress.sh
mkdir -p $JOB_DIR/ssl
chmod +x $JOB_DIR/config/certs/ssl_env.ctl
chmod +x $JOB_DIR/config/certs/gen_keystore_client.sh

if [[ -d ${JOB_DIR}/config/certs/newcerts ]]
then
 rm -rf $JOB_DIR/config/certs/newcerts/
 mkdir -p $JOB_DIR/config/certs/newcerts
else 
 mkdir -p $JOB_DIR/config/certs/newcerts
fi

chown vcap:vcap ${JOB_DIR}/config/certs/newcerts
chown vcap:vcap ${JOB_DIR}/config/certs/

mount -o remount ,exec,suid,nodev /tmp
