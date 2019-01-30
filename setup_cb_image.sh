#! /bin/bash

rm -f /tmp/ready


apt-get update

apt-get install -qq iftop sysstat

apt-get install -qq gdb

# Disable swapiness
echo 0 > /proc/sys/vm/swappiness
# Set the value in /etc/sysctl.conf so it stays after reboot.

cat >>  /etc/sysctl.conf << EOL
#
# Set swappiness to 0 to avoid swapping
vm.swappiness = 0
EOL

# Disable THP
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

cat > /etc/rc.local << EOL
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi

if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
  echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
exit 0
EOL

# Download and install CB 3.1
wget http://packages.couchbase.com/releases/3.1.0/couchbase-server-enterprise_3.1.0-ubuntu12.04_amd64.deb
dpkg -i couchbase-server-enterprise_3.1.0-ubuntu12.04_amd64.deb
/etc/init.d/couchbase-server stop

poweroff
