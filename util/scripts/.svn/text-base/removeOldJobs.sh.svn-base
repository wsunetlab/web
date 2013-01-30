#!/bin/sh

OLDDAYS=15
USERSDIR=/localhome/motelab/userdata

echo "Removing all jobs older than $OLDDAYS days old..."
echo "Current disk usage:"
df -h -l -t ext3 /dev/mapper/motelab-root

echo "About to remove the following:"
find $USERSDIR -name "job*_*" -ctime +$OLDDAYS | grep -v harvard 

find $USERSDIR -name "job*_*" -ctime +$OLDDAYS | grep -v harvard | xargs rm -r

echo "After cleanup:"
df -h -l -t ext3 /dev/mapper/motelab-root
