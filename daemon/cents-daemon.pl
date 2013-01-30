#!/usr/bin/perl -w

use strict;
use warnings;

use threads;
use threads::shared;

use DBI;
use Sys::Syslog;
use POSIX ":sys_wait_h";
use Fcntl qw(:DEFAULT :flock);

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
$_DBLOGGERNAME, $_DAEMONROOT, $_MLLOCK, $_COLLECTER);

use libml_job;
use libml_misc;
use libml_prog;

my $_AVROBJCOPYLOGFILE;
my $_REMOTEUISPLOGFILE;
my $_DBLOGGERLOGFILE;
my $_POWERMANAGEFILE;

local $SIG{__DIE__} = sub { 
  doMail($_[0]); 
  syslog("err", $_[0]); 
  closelog; 
  exit -1; 
};

local $SIG{__WARN__} = sub { 
  syslog("warning", $_[0]); 
};

openlog("motelab", "pid", "daemon");

if (not sysopen(LOCK, $_MLLOCK, O_WRONLY | O_CREAT)) {
  warn "can't open lockfile";
  closelog;
  exit -1;
}
  
if (not flock(LOCK, LOCK_EX | LOCK_NB)) {
  warn "can't lock ml_lock, Motelab must be already running: $!";
  closelog;
  exit -1;
}

syslog('info', "$_DAEMONROOT ran at " . time());

my $dbh = DBI->connect($_DSN);
unless ($dbh) {
  die "couldn't connect to database: $DBI::errstr";
}

my $lastRunningRef = killOldJobs($dbh);
if ($lastRunningRef) {
  finalizeLastJob($lastRunningRef, $dbh);
  cleanupLab($dbh, $lastRunningRef);
}
findNextJob($dbh);

closelog;
close LOCK;
exit 0;
