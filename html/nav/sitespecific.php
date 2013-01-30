<?php
  // 03 Oct 2003 : GWA : This file holds site specific information and,
  //               therefore is not included in the CVS tree.  It is, of
  //               course, required for correct operation on any given site.

  // 03 Oct 2003 : GWA : The root of the website.
  // 19 Nov 2012 : Jenis Modi: Changed www root to netlab machine

  $_WWWROOT = "localhost/web/html";
  # $_WWWROOT = "netlab.encs.vancouver.wsu.edu/web/html";
  
  // 10 Oct 2003 : GWA : The root of the user information.
  $_USERROOT = "/var/www/web/users/";
  
  // 10 Oct 2003 : GWA : Names for the subdirectories that the users use.
  $_JOBDIRNAME = "jobs";
  $_UPLOADDIRNAME = "upload";

  // 03 Oct 2003 : GWA : The DSN to use for a) authentication and b) data
  //               table creation and access.  I don't see any reason to
  //               seperate those facilities.  This MySQL user must have the
  //               correct permissions on the necessary tables or stuff will
  //               break.  Also notice that all of our administration tables
  //               live in 'auth', but this can be changed here.
  
  // 19 Nov 2012 : Jenis Modi: Changed database path to netlab machine
   $_DSN = "mysql://root:linhtinh@netlab.encs.vancouver.wsu.edu/auth";
 # $_DSN = "mysql://root:linhtinh@localhost/auth";

  // 03 Oct 2003 : GWA : Names for various tables where we hold important
  //               information.  Pretty self explanatory.  All of these
  //               tables live in the database 'auth'.
  $_JOBSTABLENAME = "jobs";
  $_FILESTABLENAME = "files";
  $_JOBFILESTABLENAME = "jobfiles";
  $_JOBSCHEDULETABLENAME = "jobschedule";
  $_SESSIONTABLENAME = "auth";
  $_MOTESTABLENAME = "motes";
  $_MYSQLTABLENAME = "mysql.user";
  $_ZONETABLENAME = "zones";
  $_PENDINGUSERTABLENAME = "pending";
  #added for topology table
  $_TOPOLOGYTABLENAME = "topology";
  $_JOBTOPOTABLENAME = "job_topology";
  
  // 03 Oct 2003 : GWA : Where to find the stylesheet.
  $_STYLESHEET = "nav/default.css";

  // 03 Oct 2003 : GWA : Session data indentifier.
  $_SESSIONINDEX = "usersettings";

  // 18 Oct 2003 : GWA : Table update command root.
  $_DATAUPDATEROOT = "/usr/bin/mysql -u root -plinhtinh -B -e";

  // 18 Oct 2003 : GWA : The directory where we store job data.
  $_JOBDATAROOT = "/var/www/web/users/";
  $_JOBDAEMON = "/var/www/web/daemon/cents-daemon.pl";

  // 30 Jan 2004 : GWA : Adding power collection.
  $_HAVEPOWERMANAGE = 1;
  
  // 19 Apr 2004 : GWA : Adding dynamic map generation
  $_IMAGETEXTSIZE = 24;
  $_IMAGEXPUSH = 4;
  $_IMAGEYPUSH = 0;
  $_SMALLIMAGEX = 591;
  $_SMALLIMAGEY = 224;
  $_CIRCLESIZE = 10;

  $_NEEDOPTIONTAB = $_HAVEPOWERMANAGE;
  $_CONNECTCACHE = "/var/www/web/html/img/connectcache/";
  $_TESTCLASSFILE = "/var/www/web/util/testClassFile.sh";
  $_JOBDAEMONEXECUTABLE = "/var/www/web/daemon/job-daemon.sh";
  $_MOTELABADMINADDRESS = "thanh.dang@vancouver.wsu.edu";
?>
