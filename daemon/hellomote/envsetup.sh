#!/bin/bash
export MAKERULES=/opt/tinyos-2.x/support/make/Makerules 
export TOSROOT=/opt/tinyos-2.x
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/lib/jvm/java-6-openjdk/bin
export TOSDIR=/opt/tinyos-2.x/tos
export CLASSPATH=/usr/lib/jvm/java-6-openjdk/lib:.:/opt/tinyos-2.x/support/sdk/java:.:/opt/tinyos-2.x/support/sdk/java/tinyos.jar:/var/www/web/daemon/phidget21.jar

/usr/bin/perl /var/www/web/daemon/hellomote/LoadPrograms.pl $1 $2 $3
