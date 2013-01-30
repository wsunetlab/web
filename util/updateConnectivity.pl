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

my @rssiArray;
my @heardArray;
my @sentArray;

require "/var/www/web/daemon/sitespecific.pl";

my $groupID = $ARGV[0];

my $ourDB = DBI->connect($_DSN)
  or die "Couldn't connect to database: $DBI::errstr\n";

my $selectGroupNumberQuery = "select distinct(groupno) from auth.connectivity" .
                             " where groupno < 5425 order by groupno desc";
my $selectGroupNumberStatement;
$selectGroupNumberStatement = $ourDB->prepare($selectGroupNumberQuery)
  or die "Couldn't prepare query '$selectGroupNumberQuery': $DBI::errstr\n";
$selectGroupNumberStatement->execute();
while (my $selectGroupNumberRef = 
    $selectGroupNumberStatement->fetchrow_hashref()) {
  my $getBrokenShitQuery = "select max(num_heard) as maxsamp" .
                           " from auth.connectivity" .
                           " where groupno=" .
                           $selectGroupNumberRef->{'groupno'} . 
                           " and frommote=3";
  my $getBrokenShitStatement;
  $getBrokenShitStatement = $ourDB->prepare($getBrokenShitQuery)
    or die "Couldn't prepare query '$getBrokenShitQuery':" .
           "$DBI::errstr\n";
  $getBrokenShitStatement->execute();
  my $getBrokenShitRef = $getBrokenShitStatement->fetchrow_hashref();
  if (!(defined($getBrokenShitRef->{'maxsamp'}))) {
    print "Skip!\n";
    next;
  }
  my $fixBrokenShitQuery = "update auth.connectivity set num_samp=" .
                           $getBrokenShitRef->{'maxsamp'} .
                           " where groupno=" .
                           $selectGroupNumberRef->{'groupno'} .
                           " and frommote=3";
  print $fixBrokenShitQuery . "\n";
  my $fixBrokenShitStatement;
  $fixBrokenShitStatement = $ourDB->prepare($fixBrokenShitQuery);
  $fixBrokenShitStatement->execute();
}
