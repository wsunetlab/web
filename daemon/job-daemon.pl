#!/usr/bin/perl

#
# NAME : job-daemon.pl
#
# PURPOSE : Used to move jobs on and off of the mote lab.
#
# NOTES:
#   1) 03 Aug 2003 : GWA : Right now this is set up to run as a cron job,
#                    perhaps every five minutes or so.  This creates slight
#                    scheduling irregularities but it's not a big problem.
#                    Eventually a more intelligent version may be written
#                    that would interact more carefully with the database to
#                    know when to sleep and wake.
#
# CREATED : 02 Aug 2003
#
# AUTHOR : GWA (gwa@post.harvard.edu)
#

use DBI;
use strict;
use Thread;
use File::Path;
use DateTime;

#
# CONSTANTS
#
# 03 Aug 2003 : GWA : These should be standardized somewhere, but for now
#               they are here.  If these change this script WILL NOT WORK.
#

our (
	$_JOBSCHEDULETABLENAME, $_DSN,              $_JOBSTABLENAME,
	$_JOBFILESTABLENAME,    $_FILESTABLENAME,   $_USERROOT,
	$_MOTEINFOTABLENAME,    $_SETMOTEID,        $_AVROBJCOPY,
	$_TMPROOT,              $_JAVAW,            $_REMOTEUISP,
	$_DBLOGGER,             $_JAR,              $_DBDUMPUSER,
	$_DBDUMPPASSWORD,       $_SESSIONTABLENAME, $_JOBDATAROOT,
	$_DATAUPDATEROOT,       $_ZIP,              $_CHOWN,
	$_CHGRP,                $_WEBUSER,          $_JOBDAEMON,
	$_HAVEPOWERCOLLECT,     $_POWERCOLLECTCMD,  $_EXTERNALSF,
	$_ERASE,                $_SFHOSTIPADDR
);

require "/var/www/web/daemon/sitespecific.pl";

my $_AVROBJCOPYLOGFILE;
my $_REMOTEUISPLOGFILE;
my $_DBLOGGERLOGFILE;
my $_POWERMANAGEFILE;
my $sfPID;

# 07 Dec 2003 : GWA : These need to be kept in synch with
#                     nav/phpdefaults.php.

my $_JOBPENDING      = 0;
my $_JOBRUNNING      = 1;
my $_JOBFINISHED     = 2;
my $_JOBSTARTPROBLEM = 3;
my $_JOBENDPROBLEM   = 4;
my $_JOBPLEASEDELETE = 5;
my $_MOTEREPROPORT   = 10001;

print "Starting of Job daemon:";
print DateTime->now()->strftime("%a, %d %b %Y %H:%M:%S %z");
print "\n";

#my $_MOTECOMMPORT = 10002;
my $_MOTECOMMPORT = 115200;
my $_MOTEPORTBASE = 9000;

# 03 Aug 2003 : GWA : Actually +1 the number of motes.

my $_DBLOGGERNAME = "dbDump";

# 06 Sep 2004 : swies : allow daemon support to be switched for testing
my $_DAEMONSUPPORT = 1;

# 03 Aug 2003 ; GWA : For timing, script output.

my $timeStart   = time();
my $outputStart = $_JOBDAEMON . " ran @ " . localtime() . "\n";
my $jobOwner    = "";

# 03 Aug 2003 : GWA : For reprogramming logic purposes.

my $oldJob = 0;
my $newJob = 0;

# 16 Oct 2003 : GWA : Adding some command-line stuff.

my $doStop    = 0;
my $doRestart = 0;

if ( $ARGV[0] eq "start" ) {
print "Argv equal to start\n";
	# 16 Oct 2003 : GWA : This is the default
}
elsif ( $ARGV[0] eq "stop" ) {
print "Argv equal to stop\n";
	# 16 Oct 2003 : GWA : Stop any job currently running and exit.
	$doStop = 1;
}
elsif ( $ARGV[0] eq "restart" ) {
print "Argv equal to restart\n";
	# 16 Oct 2003 : GWA : Stop any currently running jobs, marking the most
	#               stopped as 'unstarted' and restart that job.
	$doRestart = 1;
}

#
# CONNECT
#
# 03 Aug 2003 : GWA : First we need to access the database.  Right now one
#               database contains all of the tables that we need, which is
#               the ideal setup.
#

my $ourDB = DBI->connect($_DSN) or die "Couldn't connect to database: $DBI::errstr\n";

#my $ourDB = DBI->connect('DBI:mysql:auth:host=netlab.encs.vancouver.wsu.edu','root','linhtinh');
#  or die "Couldn't connect to database: $DBI::errstr\n";

# Jenis Added. Date: Oct 9 2012
# Use this code to rotate the stepper motor:
#java -jar rotate.jar topologyid
#put this line somewhere in the script where it should be executed only once.

#
# KILL OLD JOBS
#
# 03 Aug 2003 : GWA : Next we find out if there are running jobs that
#               need to be removed before we reschedule.  To do this we look
#               for jobs that are running and should have ended already.
#               There should only be one and it needs to be removed from the
#               lab before we can schedule something else.
#

my $runningRoot =
    "select id, jobid, start, pid, jobtempdir, dbprefix,"
  . " jobdaemon, powerpid, moteprogram,"
  . " UNIX_TIMESTAMP(start) as unixstart,"
  . " UNIX_TIMESTAMP(end) as unixend, quotacharge from "
  . $_JOBSCHEDULETABLENAME
  . " where jobdaemon=\""
  . $_JOBDAEMON . "\""
  . " and ((state="
  . $_JOBPLEASEDELETE
  . " and start <= NOW()) and pid!=0"
  . " or (state="
  . $_JOBRUNNING;
 
my $runningQuery;

# 16 Oct 2003 : GWA : If we don't care whether or not it's finished don't add
#               anything.
if ( $doStop || $doRestart ) {
	$runningQuery = $runningRoot . "))";
}
else {
	$runningQuery = $runningRoot . " and end <= NOW()))";
}

$runningQuery .= " order by unixend";
my $runningStatement;
$runningStatement = $ourDB->prepare($runningQuery)
  or die "Couldn't prepare query '$runningStatement': $DBI::errstr\n";
$runningStatement->execute();

# 03 Aug 2003 : GWA : If there's nothing running, there's nothing to do.

my $foundRunningJobs = 0;
my $nextState        = $_JOBFINISHED;
my $numberRunning    = $runningStatement->rows;

# 18 Aug 2003 : GWA : If there is more than one job marked running, then
#               a problem has occured.
#
# zone: not true anymore, looks like the JOBENDPROBLEM state is obsolete
#if ($numberRunning <= 1) {
#  $nextState = $_JOBFINISHED;
#} else {
#  $outputStart .= "\tMore than one job found marked running!  Killing all.\n";
#  $nextState = $_JOBENDPROBLEM;
#}

# 18 Aug 2003 : GWA : Find all old jobs marked 'running' in the database,
#               kill them, and update the database.

my @jobPIDs;
my $i = 0;
my @runningRefs;

# zone: we need an array of old jobs instead of lastRunningRef

while ( my $runningRef = $runningStatement->fetchrow_hashref() ) {

	# 18 Aug 2003 : GWA : Mark that we had an old job.

	$oldJob = 1;

	# 03 Aug 2003 : GWA : The normal path.  First mark the old job finished.

	# 16 Oct 2003 : GWA : We'll sneak in here in the 'restart' case.  Here we
	#               want to mark the currently running job as active 'if' it is
	#               actually the most recent.  Otherwise we'll just mark it as
	#               a problem as usual.

	# zone: we'll restart all the currently running jobs, I think this is right
	#  if ($doRestart &&
	#      ($i == $numberRunning - 1)) {
	if ($doRestart) {
		$nextState = $_JOBPENDING;
	}

	my $updateQuery =
	    "update "
	  . $_JOBSCHEDULETABLENAME
	  . " set state="
	  . $nextState
	  . " where id="
	  . $runningRef->{'id'};
	my $updateStatement;
	$updateStatement = $ourDB->prepare($updateQuery)
	  or die "Couldn't prepare query '$updateStatement': $DBI::errstr\n";
	$updateStatement->execute();

	# 18 Aug 2003 : GWA : We'll start the kill now, then continue it later if
	#               needed.

	# zone: I think the pid, powerpid, and duringrunpid stuff is allright

	print "Killing Process by pid\n";
	my $killCnt = kill 15, $runningRef->{'pid'};

	# 30 Jan 2004 : GWA : Adding support for power manangement.

	my $powerKillCnt = 0;
	if ( $runningRef->{'powerpid'} != 0 ) {
		print "killing process by powerpid\n";
		$powerKillCnt = kill 15, $runningRef->{'powerpid'};
	}

	if ( $powerKillCnt != 0 ) {
		push( @jobPIDs, $runningRef->{'powerpid'} );
	}

	my $duringRunQuery =
	    "select duringrunpid from "
	  . $_JOBSTABLENAME
	  . " where id="
	  . $runningRef->{'jobid'};

	my $duringRunStatement;
	$duringRunStatement = $ourDB->prepare($duringRunQuery)
	  or die "Couldn't prepare query '$duringRunQuery': $DBI::errstr\n";
	$duringRunStatement->execute();

	my $duringRunRef = $duringRunStatement->fetchrow_hashref();
	if ( $duringRunRef->{'duringrunpid'} != 0 ) {
		$powerKillCnt = kill 15, $duringRunRef->{'duringrunpid'};
		my $duringRunUpdate =
		    "update "
		  . $_JOBSTABLENAME
		  . " set duringrunpid=0"
		  . " where id="
		  . $runningRef->{'jobid'};

		my $duringRunUpdateStatement;
		$duringRunUpdateStatement = $ourDB->prepare($duringRunUpdate)
		  or die "Couldn't prepare query '$duringRunUpdate': $DBI::errstr\n";
		$duringRunUpdateStatement->execute();
	}

	if ( $powerKillCnt != 0 ) {
		push( @jobPIDs, $duringRunRef->{'duringrunpid'} );
	}

	#
	# 09 Mar 2004 : GWA : Hacking this up to set up seperate serial forwarders
	#               for each mote.

# zone: lets get a list of the motes this job is using right now, then only kill things associated with those
	my @currentMoteProg = ();
	my @moteProgTemp = split( /\|/, $runningRef->{'moteprogram'} );
	foreach my $moteProgEntry (@moteProgTemp) {
		my @tmp = split( /,/, $moteProgEntry );
		$currentMoteProg[ $tmp[0] ] = $tmp[1];
	}

	my $moteBasicQuery =
	    "select moteid, ip_addr, comm_port, sf_pid from "
	  . $_MOTEINFOTABLENAME
	  . " where active=1";
	my $moteBasicStatement;
	$moteBasicStatement = $ourDB->prepare($moteBasicQuery)
	  or die "Couldn't prepare query '$moteBasicQuery': $DBI::errstr\n";
	$moteBasicStatement->execute();

	# 09 Mar 2004 : GWA : Seems to make sense to do the kill and the start
	#               seperately.
	my $sfKillCnt;
	while ( my $moteBasicRef = $moteBasicStatement->fetchrow_hashref() ) {

		# zone: only kill SFs for this job's motes
		if ( defined( $currentMoteProg[ $moteBasicRef->{'moteid'} ] ) ) {
			if ( $moteBasicRef->{'sf_pid'} != 0 ) {
				print "killing process by sf_pid\n";
				$sfKillCnt = kill 15, $moteBasicRef->{'sf_pid'};
			}

			if ( $sfKillCnt != 0 ) {
				push( @jobPIDs, $moteBasicRef->{'sf_pid'} );
			}

# zone: set sf_pid to 0 here since we can't just do it for all active motes anymore
			my $moteUpdateQuery =
			    "update "
			  . $_MOTEINFOTABLENAME
			  . " set sf_pid=0"
			  . " where moteid="
			  . $moteBasicRef->{'moteid'};
			my $moteUpdateStatement;
			$moteUpdateStatement = $ourDB->prepare($moteUpdateQuery)
			  or die
			  "Couldn't prepare query '$moteUpdateQuery': $DBI::errstr\n";
			$moteUpdateStatement->execute();
		}
	}

	# 02 Sep 2003 : GWA : If we weren't able to signal the process, perhaps it
	#               went away already.  In that case, we don't need to ping it
	#               again.

	if ( $killCnt != 0 ) {
		push( @jobPIDs, $runningRef->{'pid'} );
	}

	# 03 Aug 2003 : GWA : Update output.

	$outputStart .= "\tKilled old job with jobID $runningRef->{'jobid'}\n";
	$i++;
	push( @runningRefs, $runningRef );
}

# 30 Apr 2004 : GWA : <Sigh>.  We've got to do this up here as well, just to
#               see if we need to shut the daemon down.

# zone: this shouldn't be limited to one.  Well, it's not that important since this is only used to tell if one or more pending jobs exist...

my $pendingQuery =
    "select id, jobid, start,"
  . " UNIX_TIMESTAMP(start) as unixstart,"
  . " UNIX_TIMESTAMP(end) as unixend from "
  . $_JOBSCHEDULETABLENAME
  . " where state="
  . $_JOBPENDING
  . " and start <= NOW()"
  . " and end > NOW()"
  . " order by start limit 1";
my $pendingStatement;
$pendingStatement = $ourDB->prepare($pendingQuery)
  or die "Couldn't prepare query '$pendingStatement': $DBI::errstr\n";
$pendingStatement->execute();

# zone: daemon stuff should be fine, we'll only allow those on the whole lab for now

my $needClear = 0;

# 30 Apr 2004 : GWA : Look for running daemons.
if ( $numberRunning == 0 && $_DAEMONSUPPORT != 0 ) {
	my $daemonInfoQuery =
	    "select id, postprocess, duringrunpid,"
	  . " UNIX_TIMESTAMP(lastran) as unixran,"
	  . " crontime, dbloggerpid, cacheddb from "
	  . $_JOBSTABLENAME
	  . " where cronactive=1";
	my $daemonInfoStatement;
	$daemonInfoStatement = $ourDB->prepare($daemonInfoQuery)
	  or die "Couldn't prepare query `$daemonInfoQuery': $DBI::errstr\n";
	$daemonInfoStatement->execute();
	if ( $daemonInfoStatement->rows != 0 ) {
		my $daemonInfoRef = $daemonInfoStatement->fetchrow_hashref();

		# 30 Apr 2004 : GWA : Kill if it's done or there's another job about to
		#               run.

		if (
			(
				(
					$daemonInfoRef->{'unixran'} +
					( 60 * $daemonInfoRef->{'crontime'} )
				) < $timeStart
			)
			|| ( $pendingStatement->rows > 0 )
		  )
		{
			print "killing process by dbloggerpid\n";
			my $killCnt = kill 15, $daemonInfoRef->{'dbloggerpid'};
			if ( $daemonInfoRef->{'duringrunpid'} != 0 ) {
				$killCnt = kill 15, $daemonInfoRef->{'duringrunpid'};
			}

	  #
	  # 09 Mar 2004 : GWA : Hacking this up to set up seperate serial forwarders
	  #               for each mote.

			my $moteBasicQuery =
			    "select ip_addr, comm_port, sf_pid from "
			  . $_MOTEINFOTABLENAME
			  . " where active=1";
			my $moteBasicStatement;
			$moteBasicStatement = $ourDB->prepare($moteBasicQuery)
			  or die "Couldn't prepare query '$moteBasicQuery': $DBI::errstr\n";
			$moteBasicStatement->execute();

		  # 09 Mar 2004 : GWA : Seems to make sense to do the kill and the start
		  #               seperately.
			my $sfKillCnt;
			while ( my $moteBasicRef = $moteBasicStatement->fetchrow_hashref() )
			{
				if ( $moteBasicRef->{'sf_pid'} != 0 ) {
					$sfKillCnt = kill 15, $moteBasicRef->{'sf_pid'};
					print "Killing sf_pid jobs\n";
				}
				if ( $sfKillCnt != 0 ) {
					push( @jobPIDs, $moteBasicRef->{'sf_pid'} );
				}
			}
			$needClear = 1;
			if ( $daemonInfoRef->{'postprocess'} ne "" ) {
				my $postProcessCmd =
				    $daemonInfoRef->{'postprocess'} . " "
				  . $daemonInfoRef->{'cacheddb'};
				print "************\n";
				print $postProcessCmd;
				print "**************\n";
				my $postProcessPID = fork();
				if ( $postProcessPID == 0 ) {
					exec($postProcessCmd);
				}
			}

			my $updateQuery =
			    "update "
			  . $_JOBSTABLENAME
			  . " set cronactive=0"
			  . ", duringrunpid=0"
			  . ", cacheddb=\"\""
			  . ", dbloggerpid=0"
			  . " where id="
			  . $daemonInfoRef->{'id'};
			my $updateStatement;

			$updateStatement = $ourDB->prepare($updateQuery)
			  or die
			  "Couldn't prepare query '$updateStatement': $DBI::errstr\n";
			$updateStatement->execute();
		}
	}
}

# 02 Sep 2003 : GWA : Give things a minute to die.

if ($oldJob) {
	sleep(2);
}

# 18 Aug 2003 : GWA : Finish the kill all here.  Anything that hasn't
#               exited by now we'll try and force out.

my $foundLaggart = 0;
foreach my $currentPID (@jobPIDs) {
	if ( kill( 0, $currentPID ) ) {
		$outputStart .= "\tJob with PID $currentPID needed help dying!\n";
		kill 9, $currentPID;
		$foundLaggart = 1;
	}
}

# 18 Aug 2003 : GWA : If something slowed down our killall, wait a bit for
#               it.

if ($foundLaggart) {
	sleep(5);
}

# 25 May 2004 : GWA : HACKHACK : For whatever reason sometimes the
#               serialforwarders don't want to die... this isn't so good, so
#               kill them all off here (this will also take care of killing
#               any scripts that shouldn't be
#               running.

# zone: This shouldn't be needed since we take care of the serial forwarders
#       above.  If those kills fail the administrator will just have to
#       take care of the extra processes.

#if ($oldJob || $needClear) {
#  print "running killjava script...\n";
#  print `./killjavashit`;
#  print "done\n";
#}

if ($needClear) {

	# 09 Mar 2004 : GWA : Update database for sf_pid

# zone: this code only runs after a daemon is killed, we set sf_pid to 0 when we do the kill for normal jobs

	my $moteUpdateQuery =
	  "update " . $_MOTEINFOTABLENAME . " set sf_pid=0" . " where active=1";
	my $moteUpdateStatement;
	$moteUpdateStatement = $ourDB->prepare($moteUpdateQuery)
	  or die "Couldn't prepare query '$moteUpdateQuery': $DBI::errstr\n";
	$moteUpdateStatement->execute();
}

# DATA COLLECTION

foreach my $lastRunningRef (@runningRefs) {
print "called in data collection\n";
# zone: this needs to be done for each job we stop above, so instead of lastRunningRef we should have an array of all the old jobs

	# 19 Oct 2003 : GWA : Get more, important info about the job we stopped.

	my $classesQuery =
	    "select fileid from "
	  . $_JOBFILESTABLENAME
	  . " where jobid="
	  . $lastRunningRef->{'jobid'}
	  . " and moteid=0";
	my $classesStatement;
	$classesStatement = $ourDB->prepare($classesQuery)
	  or die "Couldn't prepare query '$classesQuery': $DBI::errstr\n";
	$classesStatement->execute();

	# 19 Oct 2003 : GWA : Ack.  We also need the db prefix for this user.

	my $userQuery =
	    "select dbname, username, used from "
	  . $_SESSIONTABLENAME
	  . " as auth, "
	  . $_JOBSTABLENAME
	  . " as jobs"
	  . " where jobs.id="
	  . $lastRunningRef->{'jobid'}
	  . " and jobs.owner = auth.username";
	my $userStatement;
	$userStatement = $ourDB->prepare($userQuery)
	  or die "Couldn't prepare query '$userStatement': $DBI::errstr\n";
	$userStatement->execute();
	my $userRef = $userStatement->fetchrow_hashref();
	my $userDB  = $userRef->{'dbname'};

	# 19 Oct 2003 : GWA : First create our temporary directory.

	my $dirName = $_JOBDATAROOT . $lastRunningRef->{'jobtempdir'} . "/data/";
	print "**************\n";
	print $dirName . "\n";
	print "**************\n";

	mkpath($dirName);

	#  or die "Couldn't create data directory\n";

	# 19 Oct 2003 : GWA : Now touch each class to get data.

	my $classesRef;
	my $tableNameRoot = $lastRunningRef->{'dbprefix'};

	my $jobInfoQuery =
	    "select powermanage, postprocess from "
	  . $_JOBSTABLENAME
	  . " where id="
	  . $lastRunningRef->{'jobid'};
	my $jobInfoStatement;
	$jobInfoStatement = $ourDB->prepare($jobInfoQuery)
	  or die "Couldn't prepare query '$userStatement': $DBI::errstr\n";
	$jobInfoStatement->execute();
	my $jobInfoRef = $jobInfoStatement->fetchrow_hashref();

	if ( $jobInfoRef->{'powermanage'} ) {
		my $powerMoveCmd =
		    "mv $_JOBDATAROOT"
		  . $lastRunningRef->{'jobtempdir'}
		  . "/powerManage.log"
		  . " $_JOBDATAROOT"
		  . $lastRunningRef->{'jobtempdir'}
		  . "/data/powerManage.log";
		`$powerMoveCmd`;
	}

	if ( $jobInfoRef->{'postprocess'} ne "" ) {
		my $postProcessCmd =
		    $jobInfoRef->{'postprocess'} . " "
		  . $userRef->{'dbname'} . "."
		  . $lastRunningRef->{'dbprefix'};
		print "**************\n";
		print $postProcessCmd;
		print "**************\n";
		my $postProcessPID = fork();
		if ( $postProcessPID == 0 ) {
			exec($postProcessCmd);
		}
	}

	open( SUMMARY, ">$dirName/class.summary" );

	while ( $classesRef = $classesStatement->fetchrow_hashref() ) {
		open( DATA, ">$dirName/$classesRef->{'fileid'}.dat" );
		my $tableName = $tableNameRoot . "_" . $classesRef->{'fileid'};
		print "**************\n";
		print SUMMARY "Dumping field info for message class #"
		  . print "**************\n";
		$classesRef->{'fileid'} . "\n";
		print "**************\n";
		print SUMMARY `$_DATAUPDATEROOT "describe $userDB.$tableName"`;
		print "**************\n";
		print DATA `$_DATAUPDATEROOT "select * from $userDB.$tableName"`;
		print "**************\n";
		close DATA;
	}

	close SUMMARY;

	# 19 Oct 2003 : GWA : zip up everything.

	my $zipFile =
	    $_JOBDATAROOT
	  . $lastRunningRef->{'jobtempdir'}
	  . "/data-"
	  . $lastRunningRef->{'id'} . ".zip";
	my $zipRootDir = "$_JOBDATAROOT$lastRunningRef->{'jobtempdir'}/data";

	#print "$_ZIP $zipFile -j $zipRootDir $zipRootDir/*";
	`$_ZIP $zipFile -j $zipRootDir $zipRootDir/*`;

	# 19 Oct 2003 : GWA : Correct permissions so that the webserver can get at
	#               stuff.

	`$_CHOWN -R $_WEBUSER $_JOBDATAROOT$lastRunningRef->{'jobtempdir'}`;
	`$_CHGRP -R $_WEBUSER $_JOBDATAROOT$lastRunningRef->{'jobtempdir'}`;

	# 20 Nov 2012 : SCP script to transfer folder from lab to nelab

	my $scpScript =
	    "scp -r "
	  . $_JOBDATAROOT
	  . $lastRunningRef->{'jobtempdir'}
	  . "/ jenismodi\@netlab.encs.vancouver.wsu.edu:"
	  . $_JOBDATAROOT
	  . $lastRunningRef->{'jobtempdir'};
	`$scpScript`;
	print "Running SCP script: \n" . $scpScript;

	# 07 Dec 2003 : GWA : Update jobschedule with data path.

	my $updateQuery =
	    "update "
	  . $_JOBSCHEDULETABLENAME
	  . " set datapath=\""
	  . $zipFile . "\""
	  . " where id="
	  . $lastRunningRef->{'id'};
	my $updateStatement;
	$updateStatement = $ourDB->prepare($updateQuery)
	  or die "Couldn't prepare query '$updateStatement': $DBI::errstr\n";
	$updateStatement->execute();

	# 28 Oct 2003 : GWA : Update user quota.

# zone: we'll want to do this a different way when zones are used, but it's not too important

	my $numMinutesFreed = $lastRunningRef->{'quotacharge'};
	my $newUsed         = $userRef->{'used'} - $numMinutesFreed;

	# 12 Dec 2003 : GWA : Not sure why this is happening, but i want to prevent
	#               the user quota from going negative.
	if ( $newUsed < 0 ) {
		$newUsed = 0;
	}
	my $quotaQuery =
	    "update "
	  . $_SESSIONTABLENAME
	  . " set used="
	  . $newUsed
	  . " where username=\""
	  . $userRef->{'username'} . "\"";
	my $quotaStatement;
	$quotaStatement = $ourDB->prepare($quotaQuery)
	  or die "Couldn't prepare query '$quotaStatement': $DBI::errstr\n";
	$quotaStatement->execute();
}

if ($doStop) {
	goto FINISH;
}

#
# MARK MISSED JOBS
#
# 08 Aug 2003 : GWA : If, for some reason, we missed running a job
#               (job-daemon.pl doesn't run or whatever) we want to mark that.
#

my $missedQuery =
    "select id, jobid, start, pid,"
  . " UNIX_TIMESTAMP(start) as unixstart,"
  . " UNIX_TIMESTAMP(end) as unixend from "
  . $_JOBSCHEDULETABLENAME
  . " where state="
  . $_JOBPENDING
  . " and end <= NOW()"
  . " and jobdaemon=\""
  . $_JOBDAEMON . "\"";
my $missedStatement;
$missedStatement = $ourDB->prepare($missedQuery)
  or die "Couldn't prepare query '$missedStatement': $DBI::errstr\n";
$missedStatement->execute();

# 18 Aug 2003 : GWA : Walk through all missed jobs marking them as problems.

my $missedRef;
while ( $missedRef = $missedStatement->fetchrow_hashref() ) {

	my $updateQuery =
	    "update "
	  . $_JOBSCHEDULETABLENAME
	  . " set state="
	  . $_JOBSTARTPROBLEM
	  . " where id="
	  . $missedRef->{'id'};
	my $updateStatement;
	$updateStatement = $ourDB->prepare($updateQuery)
	  or die "Couldn't prepare query '$updateStatement': $DBI::errstr\n";
	$updateStatement->execute();
	$outputStart .= "Uh-oh: missed job $missedRef->{'jobid'}\n";
	$oldJob = 1;
}

#
# FIND NEW JOBS
#
# 03 Aug 2003 : GWA : Next we figure out if there are new jobs that need to
#               be started.  To do this we look for jobs that are pending and
#               should have started already.  Again, there should only be
#               one.  Here we retrieve the information about the job from the
#               database.  We try to reprogram the lab and update the status
#               in the database afterwards as appropriate.
#

my $pendingQuery =
    "select id, jobid, start, moteprogram,"
  . " UNIX_TIMESTAMP(start) as unixstart,"
  . " UNIX_TIMESTAMP(end) as unixend from "
  . $_JOBSCHEDULETABLENAME
  . " where state="
  . $_JOBPENDING
  . " and start <= NOW()"
  . " and end > NOW()"
  . " and jobdaemon=\""
  . $_JOBDAEMON . "\""
  . " order by start";
my $pendingStatement;
$pendingStatement = $ourDB->prepare($pendingQuery)
  or die "Couldn't prepare query '$pendingStatement': $DBI::errstr\n";
$pendingStatement->execute();

my $pendingCount = $pendingStatement->rows;
my $pendingRef;

# zone: this marking of problems isn't the way to go with zones

#if ($pendingCount > 1) {
#  $outputStart .= "More than one job found pending.  Marking problems.";
#}

# 18 Aug 2003 : GWA : Walk through all pending jobs up until the last one,
#               marking them as problems.
#for (my $index = 0; $index < $pendingCount - 1; $index++) {

#  $pendingRef = $pendingStatement->fetchrow_hashref();

# 18 Aug 2003 : GWA : Right now we KNOW that any extra pending jobs are
#               problems, so mark them that way.

#  my $updateQuery = "update " .
#                 $_JOBSCHEDULETABLENAME .
#                 " set state=" . $_JOBSTARTPROBLEM;
#                 " where id=" . $pendingRef->{'id'};
#  my $updateStatement;
#  $updateStatement = $ourDB->prepare($updateQuery)
#    or die "Couldn't prepare query '$updateQuery': $DBI::errstr\n";
#  $updateStatement->execute();
#}

#
# 30 Apr 2004 : GWA : Adding daemon support.  We try to grab an appropriate
#               daemon job in cases where nothing is actually running.

my @jobArray;    # array of ID and jobID pairs
my $isDaemonJob = 0;

# 30 Apr 2004 : GWA : <Sigh>.  We've got to do this up here as well, just to
#               see if we need to shut the daemon down.

while ( $pendingRef = $pendingStatement->fetchrow_hashref() ) {
	push(
		@jobArray,
		{
			'id'          => $pendingRef->{'id'},
			'jobid'       => $pendingRef->{'jobid'},
			'moteprogram' => $pendingRef->{'moteprogram'}
		}
	);
}

my $blahQuery =
  "select id from " . $_JOBSCHEDULETABLENAME . " where state=" . $_JOBRUNNING;
my $blahStatement;
$blahStatement = $ourDB->prepare($blahQuery)
  or die "Couldn't prepare query '$blahStatement': $DBI::errstr\n";
$blahStatement->execute();

if ( $blahStatement->rows == 0 && $pendingCount == 0 && $_DAEMONSUPPORT != 0 ) {
	my $selectDaemonQuery =
	    "select id, croncount from "
	  . $_JOBSTABLENAME
	  . " where cronjob=1 and"
	  . " (((unix_timestamp(lastran)) +"
	  . " (60 * cronfreq)) < unix_timestamp(NOW())) order by"
	  . " croncount desc limit 1";
	my $selectDaemonStatement;
	$selectDaemonStatement = $ourDB->prepare($selectDaemonQuery)
	  or die "Couldn't prepare query '$selectDaemonQuery': $DBI::errstr\n";
	$selectDaemonStatement->execute();
	if ( $selectDaemonStatement->rows ) {
		my $selectDaemonRef = $selectDaemonStatement->fetchrow_hashref();
		push(
			@jobArray,
			{
				'id'    => $selectDaemonRef->{'croncount'},
				'jobid' => $selectDaemonRef->{'id'}
			}
		);
		$isDaemonJob = 1;
	}
}

#
# 03 Aug 2003 : GWA : The normal path.  First retrieve info and try
#               to run the job

# zone: this should more or less be done in a loop for each pending job

foreach my $currentJob (@jobArray) {
	my $jobID    = $currentJob->{'id'};
	my $jobJobID = $currentJob->{'jobid'};
	$newJob = 1;

	# 31 Aug 2003 : GWA : We need some basic information about the job, like
	#               the owner.

	my $basicQuery =
	    "select owner, name, powermanage, duringrun " . "from "
	  . $_JOBSTABLENAME
	  . " where id="
	  . $jobJobID;
	my $basicStatement;
	$basicStatement = $ourDB->prepare($basicQuery)
	  or die "Couldn't prepare query '$basicQuery': $DBI::errstr\n";
	$basicStatement->execute();
	my $basicRef = $basicStatement->fetchrow_hashref();
	$jobOwner = $basicRef->{'owner'};

	#
	# 10 Oct 2003 : GWA : We need even more information.
	#

	my $moreBasicQuery =
	    "select dbname from "
	  . $_SESSIONTABLENAME
	  . " where username=\""
	  . $jobOwner . "\"";
	my $moreBasicStatement;
	$moreBasicStatement = $ourDB->prepare($moreBasicQuery)
	  or die "Couldn't prepare `$moreBasicStatement': $DBI::errstr\n";
	$moreBasicStatement->execute();
	my $moreBasicRef = $moreBasicStatement->fetchrow_hashref();
	my $databaseName = $moreBasicRef->{'dbname'};

	#
	# 09 Mar 2004 : GWA : Hacking this up to set up seperate serial forwarders
	#               for each mote.

	my @currentMoteProg = ();
	if ( $isDaemonJob == 0 ) {

   # zone: note that currentJob->{'moteprogram'} is only defined for non-daemons
		my @moteProgTemp = split( /\|/, $currentJob->{'moteprogram'} );
		foreach my $moteProgEntry (@moteProgTemp) {
			my @tmp = split( /,/, $moteProgEntry );
			$currentMoteProg[ $tmp[0] ] = $tmp[1];
		}
	}
	else {

# zone: build a currentMoteProg array for daemon jobs so we can just use that from now on

		# 31 AUG 2004: swies: use only active motes
		#my $progQuery = "select moteid, fileid from " . $_JOBFILESTABLENAME .
		#                " where jobid=" . $jobJobID;
		my $progQuery =
		    "select jobfiles.moteid, fileid from "
		  . $_JOBFILESTABLENAME
		  . " as jobfiles, "
		  . $_MOTEINFOTABLENAME
		  . " as motes"
		  . " where motes.moteid = jobfiles.moteid and"
		  . " active = 1 and"
		  . " jobid = "
		  . $jobJobID;
		my $progStatement;
		$progStatement = $ourDB->prepare($progQuery)
		  or die "Couldn't prepare query '$progStatement': $DBI::errstr\n";
		$progStatement->execute();
		while ( my $progRef = $progStatement->fetchrow_hashref() ) {
			$currentMoteProg[ $progRef->{'moteid'} ] = $progRef->{'fileid'};
		}
	}

	my $moteBasicQuery =
	    "select moteid, ip_addr, comm_port, sf_pid from "
	  . $_MOTEINFOTABLENAME
	  . " where active=1";
	my $moteBasicStatement;
	$moteBasicStatement = $ourDB->prepare($moteBasicQuery)
	  or die "Couldn't prepare query '$moteBasicQuery': $DBI::errstr\n";
	$moteBasicStatement->execute();

	# 03 Aug 2003 : GWA : The first thing is probably to set up the DBlogger.
	#               To do this we need to retrieve the class files that are
	#               used for messaging purposes and all of the mote
	#               addresses.

	# 03 Aug 2003 : GWA : Holds an array of hashes which include paths to pass
	#               to dblogger.

	my $classes;
	my $mkpathDirRoot;
	my $classPaths;

	# 03 Aug 2003 : GWA : For printing updates.
	my $classStringUpdate   = "";
	my $programStringUpdate = "";

	# 03 Aug 2003 : GWA : For holding mote info.  Indexed by moteID.
	my @moteProgram;
	my @moteLocation;

	# 19 Aug 2003 : GWA : Create temporary directory where we will store all
	#               of our important files.
	#
	# 31 Aug 2003 : GWA : We're going to make this permanent instead, just in
	#               case we want to examine these files later.

	my $tempDirUserPath;
	if ( !$isDaemonJob ) {
		$tempDirUserPath = $jobOwner . "/jobs/job" . $jobJobID . "_" . $jobID;
	}
	else {
		$tempDirUserPath =
		  $jobOwner . "/jobs/job" . $jobJobID . "_Daemon_" . $jobID;
	}
	my $tempDirPath = $_USERROOT . $tempDirUserPath;
	$_AVROBJCOPYLOGFILE = "$tempDirPath/avr-objcopy.log";
	$_REMOTEUISPLOGFILE = "$tempDirPath/remote-uisp.log";
	$_DBLOGGERLOGFILE   = "$tempDirPath/dblogger.log";
	$_POWERMANAGEFILE   = "$tempDirPath/powerManage.log";

	my $tempDir = mkpath($tempDirPath);

	#  or die "Couldn't create temp directory $tempDirPath\n";

	# zone: find the DBLogger class files
	my $classQuery =
	    "select files.path, files.name, files.user, files.type, files.id,"
	  . " jobfiles.moteid from "
	  . $_FILESTABLENAME . ", "
	  . $_JOBFILESTABLENAME
	  . " where jobfiles.jobid="
	  . $jobJobID
	  . " and jobfiles.fileid = files.id"
	  . " and jobfiles.moteid = 0";

	print "**************\n";
	print $classQuery . "\n";
	print "**************\n";

	my $classStatement;
	$classStatement = $ourDB->prepare($classQuery)
	  or die "Couldn't prepare query '$classStatement': $DBI::errstr\n";
	$classStatement->execute();
	while ( my $classRef = $classStatement->fetchrow_hashref() ) {

		# 03 Aug 2003 : GWA : Moteid == 0 means it should be a class file for
		#               messaging.  First, sanity checks.

		$classRef->{type} == "class"
		  or die "Wrong file type for message class!";

		# 19 Aug 2003 : GWA : We need to figure out the actual correct name of
		#               the java class that we are trying to use.  To do this we
		#               run javaw on it and check the error message.

		#my $javawError = `$_JAVAW $classRef->{path} 2>&1`;
		#$javawError =~ /wrong name: (.*)\)/;
		my $javaClassName = $classRef->{name};
		print "**************\n";
		print $javaClassName . "\n";
		print "**************\n";
		$javaClassName =~ s/\//\./g;

		# 03 Aug 2003 : GWA : The string $classes will hold a space seperated
		#               list of all the message class names to register.  The
		#               string $classPaths will hold a space seperated list of
		#               all the paths to the various classes, which we use to
		#               pass to jar.

		$classes .= "$javaClassName $classRef->{'id'} ";
		my $javaClassPath = $javaClassName;
		$javaClassName =~ s/\./\//g;
		my @javaClassNameArray = split( "/", $javaClassName );
		pop(@javaClassNameArray);
		my $javaFilePath = join( "/", @javaClassNameArray );
		my $javaDirRoot = shift(@javaClassNameArray);
		print "**************\n";
		print $classRef->{'path'} . "\n";
		print "Java class name: " . $javaClassName . "\n";
		print "**************\n";

		print $tempDirPath . "\n";
		print "**************\n";
		mkpath( $tempDirPath . "/jar" );

		# or die "Couldn't create jar directory\n";

		`cp $classRef->{'path'} $tempDirPath/jar/$javaClassName.class`;

		$classPaths .= "-C $tempDirPath/jar/ $javaClassName.class ";
		$classStringUpdate .=
		    "Added message class "
		  . $javaClassName
		  . " with ID "
		  . $classRef->{'id'} . "\n";
	}

### All of the above should moved together down

# zone: now we need to step through currentMoteProg, look up the files and get them ready for each mote

	my @pathCache;

	# changed loop to include currentMoteprog +1 by Jenis
	#changed again to 0 : Nov 29 2012 , testing
	# didn't work above, so added @currentmoteprog to the loop, testing
	#  for (my $moteid = 1; $moteid <= $#currentMoteProg; $moteid++) {
	print "Current mote prog size: @currentMoteProg\n";
	for ( my $moteid = 1 ; $moteid <= @currentMoteProg ; $moteid++ ) {
		my $fileid;
		print "Current mote prog:$#currentMoteProg\n";
		print "moteId:$moteid\n";

		print "**************\n";
		print "@currentMoteProg\n";
		print "Current mote program : " . @currentMoteProg . "\n";
		print "**************\n";

		print "Test 1:" . "$currentMoteProg[$moteid]\n";
		if ( defined( $currentMoteProg[$moteid] ) ) {
			$fileid = $currentMoteProg[$moteid];
			print "**************\n";
			print "fileid " . $fileid . "\n";
			print "**************\n";
		}
		else {
			print "currentMoteProg skipping ... " . "\n";
			next;
		}

		if ( !defined( $pathCache[$fileid] ) ) {

			# zone: look it up in the DB
			my $pathQuery =
			  "select path from " . $_FILESTABLENAME . " where id=" . $fileid;
			my $pathStatement;
			$pathStatement = $ourDB->prepare($pathQuery)
			  or die "Couldn't prepare query '$pathStatement': $DBI::errstr\n";

			$pathStatement->execute();
			my $pathRef = $pathStatement->fetchrow_hashref();
			$pathCache[$fileid] = $pathRef->{'path'};
		}

		# 31 Aug 2003 : GWA : This is somewhat inefficient.  We do the
		#               conversion from .exe -> .srec here, and then change the
		#               moteID as well on the way to the temp directory.  It
		#               would be smarter to do all of the .exe -> .srec at once
		#               and then work from there, but oh well.

		my $moteRoot = $tempDirPath . "/" . $moteid;
		my $moteEXE  = $moteRoot . ".exe";

		#    my $moteSREC = $moteRoot . ".srec";
		my $moteSREC = $moteRoot . ".ihex";
		$moteEXE  = "\"" . $moteEXE . "\"";
		$moteSREC = "\"" . $moteSREC . "\"";

		# 31 Aug 2003 : GWA : Some programs don't have a address to change.  In
		#               that case, we use the avr-objcopy to move the file.

 # zone: we'll probably need some sort of SETFREQUENCY program to run here FIXME

		my $setMoteID =
		    "$_SETMOTEID --exe \""
		  . $pathCache[$fileid] . "\""
		  . " $moteEXE $moteid";
		print "**************\n";
		print "setMoteId:" . "$setMoteID";
		print "**************\n";

		# 	my $avrRoot = "$_AVROBJCOPY --output-target=srec";
		my $avrRoot = "$_AVROBJCOPY --output-target=ihex";

		#print "$setMoteID\n";
		my $output = `$setMoteID`;    # 2> /dev/null`;
		print "**************\n";
		print "Output:" . "$output\n";
		print "**************\n";

		if ( $output ne "" ) {
			$avrRoot .= " \"" . $pathCache[$fileid] . "\" $moteSREC";
		}
		else {
			$avrRoot .= " $moteEXE $moteSREC";
		}

		# 31 Aug 2003 : GWA : Actually run the command and log output.
		print "Avr root:$avrRoot\n";
		print "**************\n";
		print `$avrRoot 2>&1 >> $_AVROBJCOPYLOGFILE`;
		print "**************\n";

		$moteProgram[$moteid] = $moteSREC;
		$programStringUpdate .=
		    "Added program "
		  . $pathCache[$fileid]
		  . " for mote #"
		  . $moteid . "\n";
		print "moteProgram[$moteid]:$moteProgram[$moteid]\n";
		print "**************\n";
		print $programStringUpdate . "\n";
		print "**************\n";

	}

	# 03 Aug 2003 : GWA : Here we need to retrieve mote information from
	#               the mote database.
	#
	# 31 Aug 2003 : GWA : Now we go looping through any info in the mote
	#               database reprogramming any motes that we actually have info
	#               for.
	#
	# 02 Sep 2003 : GWA : Changed to do the reprogramming via threads,
	#               hopefully cutting down on the reprogramming time once the
	#               lab gets large.

	my $moteInfoQuery =
	  "select ip_addr, moteid from " . $_MOTEINFOTABLENAME . " where active=1";
	my $moteInfoStatement;
	$moteInfoStatement = $ourDB->prepare($moteInfoQuery)
	  or die "Couldn't prepare query `$moteInfoStatement': $DBI::errstr\n";
	$moteInfoStatement->execute();

	# 30 Jan 2004 : GWA : Adding power manangement.  We'll start this up before
	#               the motes are programmed.  Hence it will show the
	#               reprogrammming cost, but that's a good way to mark the
	#               beginning of execution.

	# 30 Jan 2004 : GWA : Eventually we're going to have options here, but for
	#               now only one.

	# 30 Jan 2004 : GWA : Moved below reprogramming.

	# 03 Mar 2004 : GWA : Moved back above reprogramming.

	# zone: not entirely sure what this means for zone usage FIXME

	my $powerManagePID = 0;
	if (   $_HAVEPOWERCOLLECT
		&& $basicRef->{'powermanage'} != 0 )
	{
		my $powerManageCommand = "$_POWERCOLLECTCMD >> $_POWERMANAGEFILE";
		my $powerIDString =
		  "# Data from job " . $jobJobID . " run on " . localtime() . "\n";
		open( POWERMANAGE, ">$_POWERMANAGEFILE" );
		print POWERMANAGE $powerIDString;
		close(POWERMANAGE);

		#print $powerManageCommand;
		$powerManagePID = fork();
		if ( $powerManagePID == 0 ) {
			exec("exec $powerManageCommand");
		}
	}

#my $myFlag = 1;
# 12/19/12 2:16pm - added by Jenis and Elijah: querying for topology and applying topology config algorithm

# get topologyId from $jobJobID
# select topologyId from $_JOBSCHEDULETABLENAME where id = $jobID (this field is unique, jobid is not)
# = $topologyId
# only run algorithm IF $topologyId NOT NULL
# query topology for node and edge info
# select edges, nodes from topology where topologyId = $topologyId
# parse edges and nodes (port from java program)
# for each node: run the following on node name and connected edges
#   (disregard other constructs for now)
# Topology Table : Edges - (Starting Edge, End Edge, LinkQuality) ; Nodes - (Starting Node, angle, TRansmission Power, No of antenna, Antenna is on or of ( 15 means 1111 in binary))

	#if($myFlag == 1){
	#print "Came once\n";
	#my $topologyPID = fork();

	#if($topologyPID == 0){

# set topology id to database table first time only and other times set it to 0. 
print "starting at topology code\n";
	my $topologyId;
	my $topology_run_flag;

	my $topologyIdQuery =
	    "select topology_flag,topologyId from "
	  . $_JOBSCHEDULETABLENAME
	  .                         # get topologyId associated with job
	  " where id=" . $jobID;    # unique id
	my $topologyIdStatement;

	$topologyIdStatement = $ourDB->prepare($topologyIdQuery)
	  or die "Couldn't prepare query `$topologyIdStatement': $DBI::errstr\n";
	$topologyIdStatement->execute();

	if ( my $topologyIdRef = $topologyIdStatement->fetchrow_hashref() ) {
		$topologyId = $topologyIdRef->{'topologyId'}; # assign to topologyId (might be null)
		$topology_run_flag = $topologyIdRef->{'topology_flag'}; #get topology flag (useful to know if topology code has alreday run once. default value is "1", once topology code has run, set this value to "0" in jobschedule table;
	}

	if ( defined($topologyId) )
	{ # if topologyId not null, then job uses a topology, and so parse and run the algorithm
#check if flag is not 0, if flag is non-zero that means topology code has not run before. 
	if($topology_run_flag != "0"){
	#	my $topologyPID = fork();
	
	#	if ( $topologyPID == 0 ) {
		
	print "came in topology code at:1";
			my $dbEdges;
			my $dbNodes;

			my $topologyQuery =
			  "select edges, nodes from topology where topologyId = "
			  . $topologyId;    # get information on topology (edges and nodes)
			my $topologyStatement;

			$topologyStatement = $ourDB->prepare($topologyQuery)
			  or die
			  "Couldn't prepare query `$topologyStatement': $DBI::errstr\n";
			$topologyStatement->execute();

			if ( my $topologyRef = $topologyStatement->fetchrow_hashref() ) {
				print "Going for Topology\n";
				$dbEdges = $topologyRef->{'edges'};    # assign to edges
				$dbNodes = $topologyRef->{'nodes'};    # assign to nodes
			}
			else {
				print "cmg back to algorithm:jenis\n";
				goto ALGORITHMDONE;    # no topology, so skip algorithm
			}

# TODO: instead of parsing, we could format user data differently into the database
# (so that it's already in a format for the algorithm)

			# parse nodes
			my @nodeStrings = split( /\|/, $dbNodes );    # split nodes on "|" to get individual nodes
			my @nodes = ();    # nodeIds
			foreach my $node (@nodeStrings) {
				my @nodeSplit =
				  split( ",", $node );    # split individual node data on ","
				my $nodeId = substr( $nodeSplit[0], 1 );    # offset by 1 to ignore "("
				push( @nodes, $nodeId );         # push nodeId onto nodes
			}

			# parse edges
			my %edges = ();                      # hash of edges
			foreach my $nodeId (@nodes) {
				$edges{$nodeId} = ();    # map each node to an adjacency array (initialize here)
			}
			my @edgeStrings = split( /\|/, $dbEdges )
			  ;          # split edges on "|" to get individual edges
			foreach my $edge (@edgeStrings) {
				my @edgeSplit =
				  split( ",", $edge );    # split individual edge data on ","
				my $node1 =
				  substr( $edgeSplit[0], 1 );    # offset by 1 to ignore "("
				my $node2 =
				  substr( $edgeSplit[1], 1 );    # offset by 1 to ignore " "
				print "Node 1:$node1\n";
				print "Node 2:$node2\n";
				push( @{ $edges{$node1} }, $node2 )
				  ;    # add node2 to node1's array of connected nodes
				print "Total edges: @{$edges{$node1}}\n";

			}

			print "Total edges again :@{$edges{1}}\n";

		#	`sudo chmod 666 /dev/ttyUSB*`;        # write permission for motes
		#	`sudo chmod 666 /dev/bus/usb/*/*`;    # write permissions for usb

			# for each node, run the algorithm (right nw run once : May 23
		#	foreach my $nodeId (@nodes) {
				my $nodeId = 1;
				my $stepperSerial;
				my $stepperQuery =
				  "select stepper_serial from motes where moteid = "
				  . $nodeId;    # get stepper associated with mote
				my $stepperStatement;

				$stepperStatement = $ourDB->prepare($stepperQuery)
				  or die
				  "Couldn't prepare query `$stepperStatement': $DBI::errstr\n";
				$stepperStatement->execute();

				if ( my $stepperRef = $stepperStatement->fetchrow_hashref() ) {
					$stepperSerial =
					  $stepperRef->{'stepper_serial'}; # assign to stepperSerial
				}
				else {
					next;    # if no stepper defined for mote, skip this node
				}

				my $Lu;

#TODO: something wrong is happening at below line. Not getting Lu data as required.

				foreach my $connectedNode ( $edges{$nodeId} ) {
					print "Edges{nodeid} : $edges{$nodeId} \n";
					print "Edges node id size : @edges{$nodeId} \n";
					print "ConnectedNode: $connectedNode\n";
					$Lu .= $connectedNode . ",";
				}
				print "Node Id: " . $nodeId . "\n";
				print "Stepper Serial:" . $stepperSerial . "\n";
				print "Lu: " . $Lu . "\n";

				print `/usr/bin/perl /var/www/web/daemon/topologyConfig.pl 1 283607 2,3`;
		#	my $myTopOutput = system("/usr/bin/perl /var/www/web/daemon/topologyConfig.pl 1 283607 2,3");

		#		sleep(30);
			sleep(30);
#				print "Topology Output: $myTopOutput \n";

#print `./topologyConfig.pl $nodeId $stepperSerial $Lu`;

 #     my @algoResult = `./topologyConfig.pl 1 283607 2,3`; # apply algorithm
#    my $bestD = $algoResult[0]; # TODO: could also store these values in database from the topologyConfig script
#   my $bestP = $algoResult[1];
#my $nodeResultList = $algoResult[2];  # To zip the node ids in data folder.
#   my @Lr = split(" ", $algoResult[2]);

				# TODO: use values for error (put results into zip)
			}
#		}
#	}

	# set flag to '0'. 
	my $flagUpdateQuery = "update ". $_JOBSCHEDULETABLENAME
                          . " set topology_flag='0' where id="
                          . $jobID;
        my $flagUpdateStatement;
        $flagUpdateStatement = $ourDB->prepare($flagUpdateQuery)
            or die
        "Couldn't prepare query '$flagUpdateStatement': $DBI::errstr\n";
        $flagUpdateStatement->execute();	
	} #topology_flag_run check loop ends here
#	} #fork topologyPID loop ends
#}
	#$myFlag = 2;
	#}

  ALGORITHMDONE:

	my @threadArray;
	print "**************\n";
	print "number of mote program " . $#moteProgram . "\n";
	print "**************\n";

	while ( my $moteInfoRef = $moteInfoStatement->fetchrow_hashref() ) {
		print "**************\n";
		print " counting ...  " . "\n";
		print "**************\n";
		print "moteid:" . "$moteInfoRef->{'moteid'}\n";

		#print "Moteid Program:" . "$moteProgram[1]\n";
		#print "Moteid Program :" . "$moteProgram[2]\n";

# Jenis - added on March 27, 2013 : When disabling moteid "1", it was not giving any data, so tried to add below line according to "Motelab". If any problem comes, comment it out.

		#  if (!exists($moteProgram[$moteInfoRef->{'moteid'}])) {

		#    print " skipping ... " . "\n";
		#    next;
		#  }
		print "**************\n";
		print "Reprogramming mote " . $moteInfoRef->{'moteid'} . "\n";
		my $t = new Thread(
			\&doProgram,
			(
				$moteInfoRef->{'moteid'},
				$moteProgram[ $moteInfoRef->{'moteid'} ],
				$moteInfoRef->{'ip_addr'}
			)
		);

		#  push($duringRunUpdateStatement); # TODO: verify
		push( @threadArray, $t );
	}

	my $programmingOutput = "Started programming motes...\n";
	foreach my $currentThread (@threadArray) {
		$programmingOutput .= $currentThread->join;
	}
	$outputStart .= $programmingOutput;

	# 30 Apr 2004 : GWA : Adding support for during-job processes

	my $duringRunPID = 0;
	if ( $basicRef->{'duringrun'} ne "" ) {
		$duringRunPID = fork();
		if ( $duringRunPID == 0 ) {
			exec(   "exec "
				  . $basicRef->{'duringrun'}
				  . " > /dev/null 2> /dev/null" );
		}
		print "**************\n";
		print "duringrun = "
		  . $basicRef->{'duringrun'}
		  . " > /dev/null 2> /dev/null
\n";
	}

###DXT move SF and DBloger here

	# SerialForwarder should moved down after reprogramming the motes
	# my $sfPID;
	while ( my $moteBasicRef = $moteBasicStatement->fetchrow_hashref() ) {
print "cmg in first loop\n";
		# zone: this should be done only for the current job's motes
		if ( defined( $currentMoteProg[ $moteBasicRef->{'moteid'} ] ) ) {
print "cmg in second loop\n";
	#   my $sfCommand = "$_EXTERNALSF -comm serial\@$moteBasicRef->{'ip_addr'}:"
	#                  . "$_MOTECOMMPORT -port $moteBasicRef->{'comm_port'}" .
	#                 " -no-gui -quiet";

			my $sfCommand =
			    "$_EXTERNALSF -comm serial\@$moteBasicRef->{'ip_addr'}:"
			  . "$_MOTECOMMPORT -port $moteBasicRef->{'comm_port'}"
			  . " -no-gui -quiet";
			print "**************\n";
			print $sfCommand . "\n";
			print "**************\n";

			$sfPID = fork();
print "sfPID:$sfPID\n";
			if ( $sfPID == 0 ) {
				print before;
				print "**************\n";
				print "before executing sfCommand\n";
				print "**************\n";
# Serial forwarder getting executed here
				exec("exec $sfCommand");
				print after;
			}
			my $updateMotesQuery =
			    "update motes set sf_pid=" 
			  . $sfPID
			  . " where ip_addr=\""
			  . $moteBasicRef->{'ip_addr'} . "\"";
			my $updateMoteStatement;
			$updateMoteStatement = $ourDB->prepare($updateMotesQuery);
			$updateMoteStatement->execute();
		}
	}

### dblogger should be right after the the serial forwarder
	#$outputStart .= $classStringUpdate . $programStringUpdate;

	# 01 Sep 2003 : GWA : Time to get dblogger up and running.  First create
	#               the jar file.
	# 10 Dec 2003 : GWA : Trying to move this above the reprogramming to catch
	#               the begging of each job.

	# 10 Dec 2003 : GWA : Moved this up here to do once over to create the
	#               dblogger connect string.

# zone: this is fine since it checks for an entry in moteProgram before doing things

	my $moteInfoQuery ="select moteid, comm_port from ". $_MOTEINFOTABLENAME. " where active=1";
	my $moteInfoStatement;
	$moteInfoStatement = $ourDB->prepare($moteInfoQuery)
	  or die "Couldn't prepare query `$moteInfoStatement': $DBI::errstr\n";
	$moteInfoStatement->execute();
	#or die "Unable to execute query $DBI::errstr\n";

	my $dbLoggerConnectString;
	while ( my $moteInfoRef = $moteInfoStatement->fetchrow_hashref() ) {
		if ( exists( $moteProgram[ $moteInfoRef->{'moteid'} ] ) ) {
			$dbLoggerConnectString .=
			    "$_SFHOSTIPADDR:"
			  . "$moteInfoRef->{'comm_port'}"
			  . "::$moteInfoRef->{'moteid'} ";
		}
	}

	my $jarCommand = "$_JAR cvf $tempDirPath/classes.jar " . "$classPaths";
	print "**************\n";
	print $jarCommand . "\n";
	print "**************\n";

	#$outputStart .=  `$jarCommand 2>&1`;
	`$jarCommand 2>&1`;

	# 02 Sep 2003 : GWA : Now fork off a thread to execute the command.

	my $tablePrefix;
	if ( !$isDaemonJob ) {
		$tablePrefix = $basicRef->{'name'} . "_" . $jobID;
	}
	else {
		$tablePrefix = $basicRef->{'name'} . "_Daemon_" . $jobID;
	}

	#my $dbLoggerCommand = "$_DBLOGGER" .
	#                      " --dbUser $_DBDUMPUSER" .
	#                      " --dbPassword $_DBDUMPPASSWORD" .
	#                      " --dbNoTimestamp" .
	#                      " --dbTablePrefix $tablePrefix" .
	#                      " --dbDatabase $databaseName" .
	#                      " --redirect $_DBLOGGERLOGFILE" .
	#                      " --verbose" .
	#                      " --classLocation $tempDirPath/classes.jar" .
	#                      " --classes $classes" .
	#                      " --connect $dbLoggerConnectString";

#my $dbLoggerCommand = "$_DBLOGGER:$tempDirPath/classes.jar:$tempDirPath/jar/. dbDump" .
# DB logger changes: Jenis
	my $dbLoggerCommand =
	    "$_DBLOGGER:$tempDirPath/classes.jar dbDump"
	  . " --dbHost netlab.encs.vancouver.wsu.edu"
	  . " --dbPort 3306"
	  . " --dbUser $_DBDUMPUSER"
	  . " --dbPassword $_DBDUMPPASSWORD"
	  . " --dbNoTimestamp"
	  . " --dbTablePrefix $tablePrefix"
	  . " --dbDatabase $databaseName"
	  . " --redirect $_DBLOGGERLOGFILE"
	  . " --verbose"
	  . " --classes $classes"
	  . " --connect $dbLoggerConnectString";
	print "**************\n";
	print $dbLoggerCommand . "\n";
	print "**************\n";
	my $dbLoggerPID = fork();
	if ( $dbLoggerPID == 0 ) {

	   # 02 Sep 2003 : GWA : Little hack here suggested by david holland to make
	   #               sure that we get the right PID.

		exec("exec $dbLoggerCommand");
	}

### end of dblogger things

	# 02 Sep 2003 : GWA : We've set up everything that we can.  Now update the
	#               database.

	if ( !$isDaemonJob ) {
		my $updateQuery =
		    "update "
		  . $_JOBSCHEDULETABLENAME
		  . " set state="
		  . $_JOBRUNNING
		  . ", realstart=NOW()"
		  . ", pid="
		  . $dbLoggerPID
		  . ", powerpid="
		  . $powerManagePID
		  . ", jobtempdir=\""
		  . $tempDirUserPath . "\""
		  . ", dbprefix=\""
		  . $tablePrefix . "\""
		  . " where id="
		  . $jobID;
		my $updateStatement;
		$updateStatement = $ourDB->prepare($updateQuery)
		  or die "Couldn't prepare query '$updateStatement': $DBI::errstr\n";
		$updateStatement->execute();
		if ( $duringRunPID != 0 ) {
			my $updateQuery =
			    "update "
			  . $_JOBSTABLENAME
			  . " set duringrunpid="
			  . $duringRunPID
			  . " where id="
			  . $jobJobID;
			my $updateStatement;
			$updateStatement = $ourDB->prepare($updateQuery)
			  or die
			  "Couldn't prepare query '$updateStatement': $DBI::errstr\n";
			$updateStatement->execute();
		}
	}
	else {
		my $updateQuery =
		    "update "
		  . $_JOBSTABLENAME
		  . " set lastran=NOW()"
		  . ", croncount=(croncount + 1)"
		  . ", cronactive=1"
		  . ", duringrunpid="
		  . $duringRunPID
		  . ", cacheddb=\""
		  . $moreBasicRef->{'dbname'} . "."
		  . $tablePrefix . "\""
		  . ", dbloggerpid="
		  . $dbLoggerPID
		  . " where id="
		  . $jobJobID;
		my $updateStatement;
		$updateStatement = $ourDB->prepare($updateQuery)
		  or die "Couldn't prepare query '$updateStatement': $DBI::errstr\n";
		$updateStatement->execute();
	}

	# 18 Oct 2003 : GWA : Kind of fixed... still not sure this is correct
	#               though.

	`$_CHOWN -R $_WEBUSER $tempDirPath`;
	`$_CHGRP -R $_WEBUSER $tempDirPath`;

	$outputStart .= "\nStarted new job with jobID " . $jobJobID . "\n";
}

FINISH:

# 03 Nov 2003 : GWA : Added something to clear up lab after old jobs run if
#               there is nothing else running.

# 03 Nov 2003 : GWA : Bah... we need to find _any_ jobs about to be run.

my $pendingQuery =
    "select id from "
  . $_JOBSCHEDULETABLENAME
  . " where state="
  . $_JOBRUNNING
  . " order by start";
my $pendingStatement;
$pendingStatement = $ourDB->prepare($pendingQuery)
  or die "Couldn't prepare query '$pendingStatement': $DBI::errstr\n";
$pendingStatement->execute();

if ( $oldJob == 1 && $newJob == 0 && $pendingStatement->rows == 0 ) {
	my $moteInfoQuery =
	  "select ip_addr, moteid from " . $_MOTEINFOTABLENAME . " where active=1";
	my $moteInfoStatement;
	$moteInfoStatement = $ourDB->prepare($moteInfoQuery)
	  or die "Couldn't prepare query `$moteInfoStatement': $DBI::errstr\n";
	$moteInfoStatement->execute();

	my @threadArray;
	my $programmingOutput;
	while ( my $moteInfoRef = $moteInfoStatement->fetchrow_hashref() ) {

		my $t =
		  new Thread( \&doProgram,
			( $moteInfoRef->{'moteid'}, "", $moteInfoRef->{'ip_addr'} ) );
		push( @threadArray, $t );
	}
	foreach my $currentThread (@threadArray) {
		$programmingOutput .= $currentThread->join;
	}
	print "**************\n";
	print $programmingOutput;
	print "**************\n";
}

if ( $oldJob || $newJob ) {
	my $diff = time() - $timeStart;
	$outputStart .=
	  "jobs-daemon finished.  operation took " . $diff . " seconds\n";
	print "**************\n";
	print $outputStart;
	print "**************\n";
}
print "cmg here to exit\n";
exit(0);

sub doProgram {

# shift returns arguments passed from doProgram caller. 

	my $moteID      = shift;
	my $moteProgram = shift;

	#For Micaz: Need to copy .exe file to .srec file

	my $moteAddress = shift;
	my $moteOutput  = "Reprogramming $moteID\n";

	# my $runRoot = "$_REMOTEUISP -dprog=stk500" .
	#               " -dhost=" . $moteAddress .
	#               " -dport=" . $_MOTEREPROPORT .
	#               " -dpart=ATmega128";

	my $runRoot =
	  $_REMOTEUISP . " --telosb -c " . $moteAddress . " -r -e -I -p ";

	# " -dport=" . $_MOTEREPROPORT .
	# " -dpart=ATmega128";
	print "**************\n";
	print "Command : " . $runRoot;
	print "\n";
	print "Program: " . $moteProgram;
	print "\n";
	print "**************\n";

	if ( $moteProgram ne "" ) {
		print "**************\n";
		print "erase mote ";
		print "\n";

		#  $moteOutput .= `$runRoot --erase 2>&1`;
		#JEnis added
		my $eraseCommand =
		  $_REMOTEUISP . " --telosb -c " . $moteAddress . " -r -e -p 2>&1";
		$moteOutput .= `$eraseCommand`;

		#$moteOutput .= `$_REMOTEUISP ." --telosb -c " .$moteAddress . " -e"`;

	}
	else {

		#print "$runRoot --upload if=main.srec 2>&1\n";
		print "**************\n";
		print "upload null image";
		print "\n";

		# Jenis Added
		my $nullCommand =
		    $_REMOTEUISP
		  . " --telosb -c "
		  . $moteAddress
		  . " -r -e -I -p "
		  . $_ERASE;
		print "NullCommand:$nullCommand\n";	
	$moteOutput .= `$nullCommand`;
#	system($nullCommand);
	print "Moteoutput:$moteOutput\n";
#	sleep(5);
	  #my $eraseCommand = $_REMOTEUISP . " --telosb -c " .$moteAddress . " -e ";
	  #    $moteOutput .= `$runRoot --upload if=main.srec 2>&1`;
	  #	$moteOutput .= $runRoot;
	}

	if ( $moteProgram ne "" ) {

		#print "$runRoot --upload if=$moteProgram 1>&1\n";
		print "**************\n";
		print "upload new program";
		print "\n";

		#   $moteOutput .= `$runRoot --upload if=$moteProgram 2>&1`;
		#THANH ADDED
		my $testCmd = $runRoot . " " . $moteProgram;
		print "Execute command : " . $testCmd;
		$moteOutput .= `$testCmd`;
		print "moteoutput:";
		print "$moteOutput\n";
		print "**************\n";
	}
	return $moteOutput;
}
