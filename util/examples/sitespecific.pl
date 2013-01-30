$_JOBSCHEDULETABLENAME = "jobschedule";
$_DSN = "DBI:mysql:auth;mysql_socket=/var/lib/mysql/mysql.sock:host=localhost:user=root:password=linhtinh";
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
$_JAVABINROOT = "/user/bin/";
$_JAVAW = $_JAVABINROOT . "javaw";
$_REMOTEUISP = $_OTHERBINROOT . "netbsl";
$_CHANGEBAUDRATE = $_OTHERBINROOT . "changebaudrate";
$_DAEMONROOT = "/var/www/web/daemon/";
$_UTILROOT = "/var/www/web/util/";
$_USERROOT = "/var/www/web/users/";
$_MYSQLCONNECTORJAR = $_UTILROOT .
  "mysql-connector-java-5.0.4-bin.jar";
$_JAVA = $_JAVABINROOT . "java";
$_DBLOGGER = $_JAVA . " -Xms2m -Xmx3m" .
  " -cp /var/www/util/tinyos.jar:" .
  $_MYSQLCONNECTORJAR .
  " -jar /var/www/util/dbDump.jar";
$_DBLOGGERLOGFILE="/var/www/log/dblogger.log";
$_JAR = $_JAVABINROOT . "jar";
$_DBDUMPUSER = "root";
$_DBDUMPPASSWORD = "linhtinh";
$_DATAUPDATEROOT = "/usr/bin/mysql -u root -plinhtinh -B -e";
$_ZIP = "/usr/bin/zip";
$_TAR = "/bin/tar";
$_CHOWN = "/bin/chown";
$_CHGRP = "/bin/chgrp";
$_WEBUSER = "dangtx";
$_JOBDAEMON = $_DAEMONROOT . "cents-daemon.pl";
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
1;
