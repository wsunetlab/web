$_JOBSCHEDULETABLENAME = "jobschedule";
#$_DSN = "DBI:mysql:database=auth;mysql_socket=/var/lib/mysql/mysql.sock:host=localhost:user=root:password=linhtinh";
# 19 Nov 2012: Jenis Modi : changed database path to netlab machine
$_DSN = "DBI:mysql:database=auth:host=netlab.encs.vancouver.wsu.edu:user=root:password=linhtinh";
#$_DSN = "DBI:mysql:database=auth:host=localhost:user=root:password=linhtinh";
$_JOBSTABLENAME = "jobs";
$_JOBFILESTABLENAME = "jobfiles";
$_FILESTABLENAME = "files";
$_SESSIONTABLENAME = "auth";
$_USERSROOT = "/var/www/web/users/";
$_MOTEINFOTABLENAME = "motes";
$_ZONESTABLENAME = "zones";
$_OTHERBINROOT = "/var/www/web/bin/";
$_SFHOSTIPADDR = "127.0.0.1";
$_SETMOTEID = $_OTHERBINROOT . "set-mote-id";
$_AVRTOOLCHAINBINDIR = $_OTHERBINROOT;
$_TMPROOT = "/tmp/";
#$_JAVABINROOT = "/usr/bin/";
$_JAVABINROOT = "/usr/lib/jvm/java-6-openjdk/bin/";
$_JAVAW = $_JAVABINROOT . "java";
#$_REMOTEUISP = "/opt/bin/uisp";
$_REMOTEUISP = "/usr/bin/tos-bsl";
$_CHANGEBAUDRATE = $_OTHERBINROOT . "changebaudrate";
$_DAEMONROOT = "/var/www/web/daemon/";
$_UTILROOT = "/var/www/web/util/";
$_USERROOT = "/var/www/web/users/";
$_MYSQLCONNECTORJAR = $_UTILROOT .
  "mysql-connector-java-5.1.10-bin.jar";
$_JAVA = $_JAVABINROOT . "java";
$_DBLOGGER = $_JAVA . " -Xms2m -Xmx3m" .
  " -cp /var/www/web/util/tinyos.jar:" .
  $_MYSQLCONNECTORJAR .
  ":/var/www/web/util/dbDump.jar:.";
$_DBLOGGERLOGFILE="/var/www/log/dblogger.log";
$_JAR = $_JAVABINROOT . "jar";
$_DBDUMPUSER = "root";
$_DBDUMPPASSWORD = "linhtinh";
$_DATAUPDATEROOT = "/usr/bin/mysql -h netlab.encs.vancouver.wsu.edu -u root -plinhtinh -B -e";
#$_DATAUPDATEROOT = "/usr/bin/mysql -u root -plinhtinh -B -e";
$_ZIP = "/usr/bin/zip";
$_TAR = "/bin/tar";
$_CHOWN = "/bin/chown";
$_CHGRP = "/bin/chgrp";
#$_WEBUSER = "www-data";
$_WEBUSER = "sensors";
$_JOBDAEMON = $_DAEMONROOT . "cents-daemon.pl";
#$_JOBDAEMON = $_DAEMONROOT . "job-daemon.pl";
$_PROGRAMMING_RETRIES = 5;
$_MAILTO="thanh.dang\@vancouver.wsu.edu";
$_JOBDATAROOT = "/var/www/web/users/";
$_PROGRAMMING_TIME = 10;
$_HAVEPOWERCOLLECT = 0;
$_POWERCOLLECTCMD = "/var/www/web/util/grabPower.pl 192.168.1.190 slow";
$_MLPROGRAM = $_OTHERBINROOT . "ml-program";
($_JOBPENDING, $_JOBRUNNING, $_JOBFINISHED, $_JOBSTARTPROBLEM,
 $_JOBENDPROBLEM, $_JOBPLEASEDELETE)  = (0, 1, 2, 3, 4, 5);
$_DBLOGGERNAME     = "dbDump";
$_ERASE = "/var/www/web/daemon/blank.ihex";
$_MLLOCK = "/var/www/web/shared/ml_lock";
$_EXTERNALSF = $_JAVA . " -cp /var/www/web/util/tinyos.jar net.tinyos.sf.SerialForwarder";
#$_AVROBJCOPY = "/usr/bin/avr-objcopy";
$_AVROBJCOPY = "/usr/bin/msp430-objcopy";
1;
