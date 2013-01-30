#!/usr/bin/perl

#
# NAME : 
#
# PURPOSE :
#
# CREATED : 26 Apr 2004
#
# AUTHOR : GWA (gwa@post.harvard.edu)
#

use DBI;
use strict;

# 26 Apr 2004 : GWA : Probably don't need all of these.

our ($_JOBSCHEDULETABLENAME,
    $_DSN,
    $_JOBSTABLENAME,
    $_JOBFILESTABLENAME,
    $_FILESTABLENAME,
    $_USERROOT,
    $_MOTEINFOTABLENAME,
    $_SETMOTEID,
    $_AVROBJCOPY,
    $_TMPROOT,
    $_JAVAW,
    $_REMOTEUISP,
    $_DBLOGGER,
    $_JAR,
    $_DBDUMPUSER,
    $_DBDUMPPASSWORD,
    $_SESSIONTABLENAME,
    $_JOBDATAROOT,
    $_DATAUPDATEROOT,
    $_ZIP,
    $_CHOWN,
    $_CHGRP,
    $_WEBUSER,
    $_JOBDAEMON,
    $_HAVEPOWERCOLLECT,
    $_POWERCOLLECTCMD,
    $_EXTERNALSF,
    $_SFHOSTIPADDR);

require "sitespecific.pl";

my $startDate = $ARGV[0];
my $count = $ARGV[1];

my $ourDB = DBI->connect($_DSN)
  or die "Couldn't connect to database: $DBI::errstr\n";

for (my $dateCount = 0; $dateCount < $count; $dateCount++) {
  my $startDateQuery = "select DATE_ADD('$startDate', INTERVAL " .
                       $dateCount . " DAY) as startDate";
  my $startDateStatement;
  $startDateStatement = $ourDB->prepare($startDateQuery);
  $startDateStatement->execute();
  my $startDateRef = $startDateStatement->fetchrow_hashref();
  my $innerStartDate = $startDateRef->{'startDate'};

  my $usageQuery = 
    "select (sum(UNIX_TIMESTAMP(end) - UNIX_TIMESTAMP(start)) / 86400)" . 
    " as usageAmount from jobschedule" .
    " where (UNIX_TIMESTAMP(end) >" .
    " UNIX_TIMESTAMP(DATE_ADD('$startDate', INTERVAL $dateCount DAY)))" . 
    " and (UNIX_TIMESTAMP(end) <" .
    " UNIX_TIMESTAMP(DATE_ADD('$startDate', INTERVAL " . ($dateCount + 1) . 
    " DAY))) and datapath!=\"\"";
  #print "$usageQuery\n";
  my $usageStatement;
  $usageStatement = $ourDB->prepare($usageQuery);
  $usageStatement->execute();
  my $usageRef = $usageStatement->fetchrow_hashref();
  my $usageAmount = $usageRef->{'usageAmount'};
  if (!defined($usageAmount)) {
    $usageAmount = 0;
  }
  print STDERR "$innerStartDate\t$usageAmount\n";
}
