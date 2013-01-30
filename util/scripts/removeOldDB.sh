#!/bin/sh

OLDDAYS=30

echo "Removing all jobs older than $OLDDAYS days old..."
echo "Current disk usage:"
df -h -l -t ext3 /dev/mapper/motelab-root

echo "About to remove the following:"
mysql -u auth -pauth auth -N -B -e "select dbname from auth where username not like '%harvard%'" | xargs -n 1 --replace=BLAH find /var/lib/mysql/BLAH -type f \( -iname "*.frm" -o -iname "*.myd" -o -iname "*.myi" \) -ctime +$OLDDAYS

mysql -u auth -pauth auth -N -B -e "select dbname from auth where username not like '%harvard%'" | xargs -n 1 --replace=BLAH find /var/lib/mysql/BLAH -type f \( -iname "*.frm" -o -iname "*.myd" -o -iname "*.myi" \) -ctime +$OLDDAYS | xargs rm -r

echo "After cleanup:"
df -h -l -t ext3 /dev/mapper/motelab-root
