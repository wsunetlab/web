# Copyright (c) 2005 Bret Hull, Kyle Jamieson, Geoffrey Werner-Allen
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# $Id: libml_job.pm,v 1.11 2008/04/06 16:36:31 gwamotelab Exp $

use strict;
use warnings;

require "sitespecific.pl";

our ($_JOBSCHEDULETABLENAME, $_DSN, $_JOBSTABLENAME,
$_JOBFILESTABLENAME, $_FILESTABLENAME, $_USERROOT,
$_MOTEINFOTABLENAME, $_SETMOTEID, $_AVROBJCOPY, $_TMPROOT, $_JCFDUMP,
$_REMOTEUISP, $_DBLOGGER, $_JAR, $_DBDUMPUSER, $_DBDUMPPASSWORD,
$_SESSIONTABLENAME, $_JOBDATAROOT, $_DATAUPDATEROOT, $_ZIP,
$_PROGRAMMING_RETRIES, $_MAILTO, $_CHOWN, $_PROGRAMMING_TIME, $_CHGRP,
$_WEBUSER, $_JOBDAEMON, $_HAVEPOWERCOLLECT, $_POWERCOLLECTCMD,
$_EXTERNALSF, $_SFHOSTIPADDR, $_BLANK, $_MLPROGRAM, $_JOBPENDING,
$_JOBRUNNING, $_JOBFINISHED, $_JOBSTARTPROBLEM, $_JOBENDPROBLEM,
$_JOBPLEASEDELETE, $_MOTEREPROPORT, $_MOTECOMMPORT, $_MOTEPORTBASE,
$_DBLOGGERNAME, $_DBDUMPHOST, $_TAR, $_ERASE, $_COLLECTER, $_MESSAGECLASS,
$_DBLOGGERPATH, $_JAVA);

sub findNextJob($) {
  my ($dbh) = @_;
  
  my $pendingRef;
  my $pendingStatement = getPendingJob($dbh);
     
  if ($pendingRef = $pendingStatement->fetchrow_hashref()) {
  
    my $basicRef = getJobInfo($dbh, $pendingRef->{'jobid'});
    my $jobOwner = $basicRef->{'owner'};
    my $databaseName = getJobDB($dbh, $jobOwner);
    my $zoneID = $pendingRef->{'zoneid'};

    syslog("info", "found pending run %s of job %d for %s", 
           $pendingRef->{'id'}, $pendingRef->{'jobid'}, $jobOwner);

    my ($classes, $classPaths);
    my $classStringUpdate   = "";
    my $programStringUpdate = "";
    my @moteProgram;

    my ($avrLogFile, $uispLogFile, $dblErrorFile, $dblClassFile, $powerLogFile,
        $mlProgramLogFile, $sfLogFile);
    my ($tempDirPath, $tempDirUserPath);

    updateTempDir($pendingRef->{'jobid'}, $pendingRef->{'id'},
                  \$tempDirPath, \$tempDirUserPath,
                  \$avrLogFile, \$uispLogFile, \$dblErrorFile,
                  \$dblClassFile,
                  \$powerLogFile, \$mlProgramLogFile, \$sfLogFile,
                  $jobOwner);

    # 17 Jul 2006 : GWA : This is named screwy. getClassInfo() actually gets
    #               _all_ of the file information for this job, not just
    #               classes.

    my $fileInfoArrayRef  = getFilesInfo($dbh, $pendingRef, $basicRef);
    foreach my $fileRef (@{$fileInfoArrayRef}) {
      if ($fileRef->{'moteid'} == 0) {
        handleClassFiles($fileRef, \$classes, \$classPaths,
                         \$classStringUpdate, $tempDirPath);
      } else {
        handleMoteBinaries($fileRef, \$programStringUpdate,
                           \@moteProgram, $tempDirPath, 
                           $avrLogFile);
      }
    }

    my $powerLoggerPID = 0;
    if (($_HAVEPOWERCOLLECT == 1) &&
        ($basicRef->{'powermanage'} == 1)) {
      $powerLoggerPID = forkPowerLogger($powerLogFile, $pendingRef->{'jobid'});
    }
    
    reprogramMotes($dbh, \@moteProgram, $mlProgramLogFile, $jobOwner, 1, $zoneID, 1);
   
    # 14 Feb 2009 : GWA : Back to doing this down here. We don't start the SF
    #               on the node until after programming anyway, so anything
    #               sent immediately to the serial port will be lost.  Tough.
    #               Use a startup timer or something.
    
    my $dbLoggerPID = forkDBLogger($dbh, $tempDirPath, $classPaths,
                                   $pendingRef, $basicRef, $databaseName,
                                   $classes, \@moteProgram,
                                   $dblErrorFile, $dblClassFile);
    
    my $collecterPID = forkCollecter($dbh, $tempDirPath, $classPaths,
                                     $pendingRef, $basicRef, $databaseName,
                                     $classes, \@moteProgram,
                                     $dblErrorFile, $dblClassFile);
 

    syslog("info", "dblogger[$dbLoggerPID] run $pendingRef->{'id'} " .
                   "of job $pendingRef->{'jobid'} logging to " .  $dblErrorFile);
   
    if ($basicRef->{'duringrun'} ne "") {
      startDuringRun($dbh, 
                     $basicRef->{'duringrun'}, 
                     $pendingRef->{'id'}, 
                     $pendingRef->{'jobid'});
    }
    syslog("info", "reprogrammed run $pendingRef->{'id'} of job " .
                   $pendingRef->{'jobid'} . " logged to " .
                   $mlProgramLogFile);
  
    markJobRunning($dbh, $dbLoggerPID, $tempDirUserPath, 
                   $basicRef, $pendingRef, $powerLoggerPID, $collecterPID);
    
    `$_CHOWN -R $_WEBUSER $tempDirPath`;
    `$_CHGRP -R $_WEBUSER $tempDirPath`;

    syslog("info", 
  "marked run $pendingRef->{'id'} of job $pendingRef->{'jobid'} as started");

    # 14 Jul 2006 : GWA : Do more cleanup.

    foreach my $fileRef (@{$fileInfoArrayRef}) {
      cleanupExperimentFile($fileRef, $tempDirPath);
    }

    syslog("info", "cleaned up binaries of run $pendingRef->{'id'}, job $pendingRef->{'jobid'}");
  }
}

###############################################################################

sub getPendingJob($) {
  my ($dbh) = @_;
  my $pendingQuery = qq{SELECT id, jobid, start, zoneid,
                               UNIX_TIMESTAMP(start) AS unixstart, 
                               UNIX_TIMESTAMP(end) AS unixend 
                        FROM $_JOBSCHEDULETABLENAME 
                        WHERE state = $_JOBPENDING AND start <= NOW()
                        AND end > NOW() AND jobdaemon="$_JOBDAEMON"
                        ORDER BY start};
  my $pendingStatement = $dbh->prepare($pendingQuery);
  unless ($pendingStatement) {
    syslog("error", "couldn't prepare $pendingStatement");
    return;
  }
  $pendingStatement->execute();

  my $pendingCount = $pendingStatement->rows;

  # 18 Aug 2003 : GWA : Walk through all pending jobs up until the last one,
  #               marking them as problems.
  my $pendingRef;
  for (my $index = 0; $index < $pendingCount - 1; $index++) {
    $pendingRef = $pendingStatement->fetchrow_hashref();

    syslog("warning", 
      "setting job $pendingRef->{'id'} to state $_JOBSTARTPROBLEM");

    my $updateQuery = "UPDATE $_JOBSCHEDULETABLENAME 
                       SET state = $_JOBSTARTPROBLEM 
                       WHERE id = $pendingRef->{'id'}";
    my $updateStatement;
    $updateStatement = $dbh->prepare($updateQuery);
    unless ($updateStatement) {
      syslog("error", "couldn't prepare $updateStatement");
      return;
    }
    $updateStatement->execute();
    syslog("warning", "marked job $pendingRef->{'id'} as late");
  }
  return $pendingStatement;
}

###############################################################################

sub killOldJobs($) {
  my ($dbh) = @_;
  my $lastRunningRef = '';

  my $runningQuery = qq{SELECT id, 
                               jobid, 
                               start, 
                               pid, 
                               jobtempdir, 
                               zoneid, 
                               dbprefix, 
                               jobdaemon, 
                               UNIX_TIMESTAMP(start) AS unixstart, 
                               UNIX_TIMESTAMP(end) AS unixend, 
                               quotacharge, 
                               state, 
                               powerpid, 
                               cacheddb, 
                               duringrunpid 
                        FROM $_JOBSCHEDULETABLENAME 
                        WHERE jobdaemon="$_JOBDAEMON" 
                              AND ((state = $_JOBPLEASEDELETE AND start <= NOW()) 
                                AND pid != 0 OR (state = $_JOBRUNNING 
                                  AND end <= NOW())) 
                        ORDER BY unixend};

  my $runningStatement = $dbh->prepare($runningQuery);
  unless ($runningStatement) {
    die("couldn't prepare $runningQuery");
  }
  $runningStatement->execute();

  my $foundRunningJobs = 0;
  my $nextState;
  my $numberRunning = $runningStatement->rows;
  if ($numberRunning <= 1) {
    $nextState = $_JOBFINISHED;
  } else {
    syslog("warning", "more than one job found running; killing all");
    $nextState = $_JOBENDPROBLEM;
  }

  my @jobPIDs;
  my $numRunning = 0;

  while (my $runningRef = $runningStatement->fetchrow_hashref()) {
    my $updateQuery = "UPDATE $_JOBSCHEDULETABLENAME SET 
      state = $nextState, realend = NOW() 
      WHERE id = $runningRef->{'id'}";
    my $updateStatement;
    $updateStatement = $dbh->prepare($updateQuery)
      or die "Couldn't prepare query '$updateStatement': $DBI::errstr\n";
    $updateStatement->execute();

    syslog("info", "setting job %d state from %d to %d",
           $runningRef->{'id'}, $runningRef->{'state'}, $nextState);
    
    my $killCnt = kill 15, $runningRef->{'pid'};
    if ($killCnt != 0) {
      push(@jobPIDs, $runningRef->{'pid'});
    } else {
      syslog("info", "couldn't find pid $runningRef->{'pid'}");
    }
    
    if ($runningRef->{'powerpid'} != 0) {
      my $powerKillCnt = kill 15, $runningRef->{'powerpid'};
      if ($powerKillCnt != 0) {
        push(@jobPIDs, $runningRef->{'powerpid'});
      } else {
        syslog("info", "couldn't find pid $runningRef->{'powerpid'}");
      }
    }
    
    if ($runningRef->{'duringrunpid'} != 0) {
      my $powerKillCnt = kill 15, $runningRef->{'duringrunpid'};
      if ($powerKillCnt != 0) {
        push(@jobPIDs, $runningRef->{'duringrunpid'});
      } else {
        syslog("info", "couldn't find pid $runningRef->{'duringrunpid'}");
      }
    }

    $numRunning++;
    $lastRunningRef = $runningRef;
  }

  if (@jobPIDs > 0) {
    syslog("info", "sleeping to allow processes to die");
    sleep 20;
  }

  if ($numRunning > 0) {
    syslog("info", "sent signal 15 to $numRunning jobs' processes")
  }

  foreach my $currentPID (@jobPIDs) {
    if (kill(0, $currentPID)) {
      syslog("warning", "pid $currentPID needed help dying");
      kill 9, $currentPID;
      waitpid($currentPID, WNOHANG);
    }
  }
  
  return $lastRunningRef;
}

###############################################################################

sub finalizeLastJob ($$) {
  my $lastRunningRef = shift;
  my $dbh = shift;
  
  my $classesQuery = "SELECT fileid FROM $_JOBFILESTABLENAME WHERE
  jobid = $lastRunningRef->{'jobid'} AND moteid = 0";
                      
  my $classesStatement = $dbh->prepare($classesQuery);
  unless ($classesStatement) {
    syslog("error", "couldn't prepare $classesQuery");
    return;
  }
  $classesStatement->execute();

  my $jobInfoQuery = "SELECT postprocess FROM $_JOBSTABLENAME WHERE jobs.id =
  $lastRunningRef->{'jobid'}";
  my $jobInfoStatement = $dbh->prepare($jobInfoQuery);
  unless ($jobInfoStatement) {
    syslog("error", "couldn't prepare $jobInfoQuery");
    return;
  }
  $jobInfoStatement->execute();
  my $jobInfoRef = $jobInfoStatement->fetchrow_hashref();

  my $userQuery = "SELECT dbname, username, used 
    FROM $_SESSIONTABLENAME AS auth, $_JOBSTABLENAME AS jobs 
    WHERE jobs.id = $lastRunningRef->{'jobid'} AND 
          jobs.owner = auth.username";

  my $userStatement = $dbh->prepare($userQuery);
  unless ($userStatement) {
    syslog("error", "couldn't prepare $userQuery");
    return;
  }
  $userStatement->execute();

  my $userRef = $userStatement->fetchrow_hashref();
  my $userDB = $userRef->{'dbname'};

  my $dirName = $_JOBDATAROOT . $lastRunningRef->{'jobtempdir'} . "/data";
  mkdir($dirName) unless -d $dirName;
  unless (-d $dirName) {
    syslog("error", "couldn't create directory $dirName");
    return;
  }
  
  # 19 Oct 2003 : GWA : Now touch each class to get data.
  
  my $classesRef;
  my $tableNameRoot = $lastRunningRef->{'dbprefix'};

  open(SUMMARY, ">$dirName/class.summary");
  
  while ($classesRef = $classesStatement->fetchrow_hashref()) {
    open(DATA, ">$dirName/$classesRef->{'fileid'}.dat");
    my $tableName = $tableNameRoot . "_" . $classesRef->{'fileid'};
    print SUMMARY "Dumping field info for message class #" .
                  $classesRef->{'fileid'} . "\n";
    print SUMMARY `$_DATAUPDATEROOT "describe $userDB.$tableName"`;
    print DATA `$_DATAUPDATEROOT "select * from $userDB.$tableName"`;
    close DATA;
  }

  close SUMMARY;
  
  # 22 Mar 2005 : GWA : Grab power data.

  if ($lastRunningRef->{'powerpid'} != 0) {
    my $powerMoveCmd = "mv $_JOBDATAROOT" .
                       $lastRunningRef->{'jobtempdir'} .
                       "/powerManage.log" .
                       " $_JOBDATAROOT" .
                       $lastRunningRef->{'jobtempdir'} .
                       "/data/powerManage.log";
    `$powerMoveCmd`;
    syslog("info", "moving power data to archive");
  }
 
  `rm $_JOBDATAROOT/$lastRunningRef->{'jobtempdir'}/dbDump.jar`;

  my $logMoveCmd = "mv $_JOBDATAROOT" .
                     $lastRunningRef->{'jobtempdir'} .
                     "/messages.pickle.gz" .
                     " $_JOBDATAROOT" .
                     $lastRunningRef->{'jobtempdir'} .
                     "/data/";
  `$logMoveCmd`;

  my $logCopyCmd = "cp $_JOBDATAROOT" .
                     $lastRunningRef->{'jobtempdir'} .
                     "/DBLOGGER.CLASSES" .
                     " $_JOBDATAROOT" .
                     $lastRunningRef->{'jobtempdir'} .
                     "/DBLOGGER.ERRORS" .
                     " $_JOBDATAROOT" .
                     $lastRunningRef->{'jobtempdir'} .
                     "/REPROGRAM.LOG" .
                     " $_JOBDATAROOT" .
                     $lastRunningRef->{'jobtempdir'} .
                     "/data/";
  `$logCopyCmd`;
  syslog("info", "moving logs to archive");

  my $zipRootDir = "data";
  my $zipRootDest = $zipRootDir . "-" . $lastRunningRef->{'id'};
  my $zipFile = $_JOBDATAROOT . $lastRunningRef->{'jobtempdir'} .
                "/data-" . $lastRunningRef->{'id'} . ".tar.gz";
  syslog("info", "$_ZIP -r $zipFile $zipRootDir");
  chdir("$_JOBDATAROOT$lastRunningRef->{'jobtempdir'}/");
  `mv $zipRootDir $zipRootDest`;
  `$_TAR czf $zipFile $zipRootDest`;
  
  # 15 Feb 2007 : GWA : Um, lets get rid of the temporary directory!
  `rm $zipRootDest/*`;
  rmdir($zipRootDest);

  # 19 Oct 2003 : GWA : Correct permissions so that the webserver can get at
  #               stuff.

  `$_CHOWN -R $_WEBUSER $_JOBDATAROOT$lastRunningRef->{'jobtempdir'}`;
  `$_CHGRP -R $_WEBUSER $_JOBDATAROOT$lastRunningRef->{'jobtempdir'}`;
  
  # 07 Dec 2003 : GWA : Update jobschedule with data path.

  my $updateQuery = "update " .
                 $_JOBSCHEDULETABLENAME .
                 " set datapath=\"" . $zipFile . "\"" .
                 " where id=" . $lastRunningRef->{'id'};
  my $updateStatement;
  $updateStatement = $dbh->prepare($updateQuery)
    or die "Couldn't prepare query '$updateStatement': $DBI::errstr\n";
  $updateStatement->execute();
  
  # 28 Oct 2003 : GWA : Update user quota.
  # 03 Aug 2008 : GWA : Let's be somewhat sane about this.

  my $newUsed = `mysql -u auth -pauth auth -B -N -e \"select sum(quotacharge) from jobs, jobschedule where jobs.id=jobschedule.jobid and owner=\\\"$userRef->{'username'}\\\" and state=0 and start>NOW()"`;
  chomp($newUsed);
  if ($newUsed eq "NULL") {
    $newUsed = 0;
  }
  
  # 12 Dec 2003 : GWA : Not sure why this is happening, but i want to prevent
  #               the user quota from going negative.
  if ($newUsed < 0) {
    $newUsed = 0;
  }
  my $quotaQuery = "update " . $_SESSIONTABLENAME . 
                   " set used=" . $newUsed .
                   " where username=\"" . $userRef->{'username'} . "\"";
  my $quotaStatement;
  $quotaStatement = $dbh->prepare($quotaQuery) 
    or die "Couldn't prepare query '$quotaStatement': $DBI::errstr\n";
  $quotaStatement->execute();

  # 25 Oct 2005 : GWA : Adding after-run process support.
  
  if ($jobInfoRef->{'postprocess'} ne "") {
    my $postProcessCmd = $jobInfoRef->{'postprocess'} . " " . 
                         $userRef->{'dbname'} . "." .
                         $lastRunningRef->{'cacheddb'};
    my $postProcessPID = fork();
    if ($postProcessPID == 0) {
      exec($postProcessCmd);
    }
  }
}

sub cleanupLab($$) {
  my $dbh = shift;
  my $lastRunningRef = shift;
  my $zoneID = $lastRunningRef->{'zoneid'}; 

  # 17 Jul 2006 : GWA : FIXME, ZONE.

  my $moteInfoQuery = qq{SELECT ip_addr, 
                                moteid 
                         FROM $_MOTEINFOTABLENAME WHERE active=1};
  my $moteInfoStatement = $dbh->prepare($moteInfoQuery);
  unless ($moteInfoStatement) {
    syslog("error", "couldn't prepare $moteInfoStatement");
    return;
  }
  $moteInfoStatement->execute();
  
  my @moteProgram;
  my %ipAddrHash;
  while (my $moteInfoRef = $moteInfoStatement->fetchrow_hashref()) {
    @moteProgram[$moteInfoRef->{'moteid'}] = "$_ERASE";
  }
  reprogramMotes($dbh, \@moteProgram, "/dev/null", "", 0, $zoneID, 0);

  syslog("info", "erased testbed");
}

sub forkDBLogger($$$$$$$\@$$) {
  my ($dbh, $tempDirPath, $classPaths, $pendingRef,
      $basicRef, $databaseName, $classes, $moteProgram, $logFile,
      $dbLoggerInfoFile) = @_;  
  my $moteInfoQuery = "select moteid, comm_port, comm_host from " . $_MOTEINFOTABLENAME .
                      " where active=1";
  my $moteInfoStatement;
  $moteInfoStatement = $dbh->prepare($moteInfoQuery) 
    or die "Couldn't prepare query `$moteInfoStatement': $DBI::errstr\n";
  $moteInfoStatement->execute();

  my $dbLoggerConnectString;
  while (my $moteInfoRef = $moteInfoStatement->fetchrow_hashref()) {

    if (!exists($moteProgram->[$moteInfoRef->{'moteid'}])) {
      next;
    }
    $dbLoggerConnectString .= "$moteInfoRef->{'comm_host'}:" . 
                              "$moteInfoRef->{'comm_port'}" .
                              "::$moteInfoRef->{'moteid'} ";
  }

  `cp $_DBLOGGERPATH $tempDirPath/dbDump.jar`;
  my $jarCommand = "$_JAR uf $tempDirPath/dbDump.jar" .
                   " $classPaths";

  syslog("info", "$jarCommand");
  `$jarCommand 2>&1`;
  
  `rm -rf $tempDirPath/jar/`;

  my $dbLoggerCommand = "$_JAVA -jar $tempDirPath/dbDump.jar" .
                        " --dbUser $_DBDUMPUSER" .
                        " --dbPassword $_DBDUMPPASSWORD" .
                        " --dbNoTimestamp" .
                        " --dbTablePrefix $basicRef->{'name'}" .
                        "_$pendingRef->{'id'}" .
                        " --dbDatabase $databaseName" .
                        " --redirectError $logFile" .
                        " --redirectOutput $dbLoggerInfoFile" .
                        " --classes $classes" . 
                        " --connect $dbLoggerConnectString";

  # Fork the DB Logger
  syslog("info", "$dbLoggerCommand");
  my $dbLoggerPID = fork();
  if ($dbLoggerPID == 0) {
    exec("exec $dbLoggerCommand");
  }
  
  return $dbLoggerPID; 
}

sub forkCollecter($$$$$$$\@$$) {
  my ($dbh, $tempDirPath, $classPaths, $pendingRef,
      $basicRef, $databaseName, $classes, $moteProgram, $logFile,
      $dbLoggerInfoFile) = @_;  
  my $moteInfoQuery = "select moteid, comm_port, comm_host from " . $_MOTEINFOTABLENAME .
                      " where active=1";
  my $moteInfoStatement;
  $moteInfoStatement = $dbh->prepare($moteInfoQuery) 
    or die "Couldn't prepare query `$moteInfoStatement': $DBI::errstr\n";
  $moteInfoStatement->execute();

  my $dbLoggerConnectString;
  while (my $moteInfoRef = $moteInfoStatement->fetchrow_hashref()) {

    if (!exists($moteProgram->[$moteInfoRef->{'moteid'}])) {
      next;
    }
    $dbLoggerConnectString .= "$moteInfoRef->{'comm_host'}:" . 
                              "$moteInfoRef->{'comm_port'}" .
                              ":$moteInfoRef->{'moteid'} ";
  }

  my $collecterCommand = "$_COLLECTER" .
                         " --pickleoutput=$tempDirPath/messages.pickle.gz" .
                         " motelab:20000" .
                         " $dbLoggerConnectString";

  # 12 Feb 2009 : GWA : Fork the SF collecter.
  
  syslog("info", "$collecterCommand");
  $ENV{TOSROOT} = "/opt/tinyos-2.1.0/";
  my $collecterPID = fork();
  if ($collecterPID == 0) {
    exec("exec $collecterCommand");
  }

  return $collecterPID; 
}

sub forkPowerLogger($) {
  my ($powerLoggerFile, $jobJobID) = @_;
  my $powerIDString = "# Data from job " . $jobJobID .
                      " run on " . localtime() . "\n";
  open(POWERMANAGE, ">$powerLoggerFile");
  print POWERMANAGE $powerIDString;
  close(POWERMANAGE);
  my $powerLoggerCommand = "$_POWERCOLLECTCMD 2>&1 >> $powerLoggerFile";
  my $powerLoggerPID = fork();
  if ($powerLoggerPID == 0) {
    exec("exec $powerLoggerCommand");
  }
  return $powerLoggerPID;
}
1;
