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
    $_CONNECTDSN,
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
    $_SFHOSTIPADDR,
    $_CONNECTCACHE,
    $_MOTELABROOT,
    $_SMALLIMAGEX,
    $_SMALLIMAGEY);

my @rssiArray;
my @heardArray;
my @sentArray;

require "sitespecific.pl";

my $connectTableRoot = $ARGV[0];
my $_CONNECTDATATABLENAME = $connectTableRoot . "_3";
my $_CONNECTCONTROLTABLENAME = $connectTableRoot . "_2";

my $ourDB = DBI->connect($_CONNECTDSN)
  or die "Couldn't connect to database: $DBI::errstr\n";

# 26 Apr 2004 : GWA : Since this table is going to be static, and might be
#               added to as we run, let's figure out where to start and end
#               processing.

my $startEndQuery = "select MAX(motelabSeqNo) as maxSeq," .
                    " MIN(motelabSeqNo) as minSeq from " .
                    $_CONNECTDATATABLENAME;
my $startEndStatement;
$startEndStatement = $ourDB->prepare($startEndQuery)
  or die "Couldn't prepare query '$startEndQuery': $DBI::errstr\n";
$startEndStatement->execute() or die "Table doesn't exist.";
my $startEndRef = $startEndStatement->fetchrow_hashref();
my $startIndex = $startEndRef->{'minSeq'};
my $endIndex = $startEndRef->{'maxSeq'};

my $getAllMotesQuery = "select distinct sourceaddr from " .
                       $_CONNECTDATATABLENAME .
                       " where motelabSeqNo >= " . $startIndex .
                       " and motelabSeqNo <= " . $endIndex . " ORDER BY sourceaddr";
my $getAllMotesStatement;
$getAllMotesStatement = $ourDB->prepare($getAllMotesQuery)
  or die "Couldn't prepare query '$getAllMotesQuery': $DBI::errstr\n";
$getAllMotesStatement->execute();

while (my $getAllMotesRef = $getAllMotesStatement->fetchrow_hashref()) {
  my $currentMote = $getAllMotesRef->{'sourceaddr'};
  print STDERR "$currentMote\n";
  my $startEndEpochQuery = "select MAX(cur_seqno) as maxSeq, " .
                           " MIN(cur_seqno) as minSeq from " .
                           $_CONNECTCONTROLTABLENAME . 
                           " where sourceaddr=" . $currentMote;
  my $startEndEpochStatement;
  $startEndEpochStatement = $ourDB->prepare($startEndEpochQuery)
    or die "Couldn't prepare query '$startEndEpochQuery': $DBI::errstr\n";
  $startEndEpochStatement->execute();
  my $startEndEpochRef = $startEndEpochStatement->fetchrow_hashref();
  my $startEpochIndex = $startEndEpochRef->{'minSeq'};
  my $endEpochIndex = $startEndEpochRef->{'maxSeq'};
  $sentArray[$currentMote] = ($endEpochIndex - $startEpochIndex + 1);
  my $getMotesHeardQuery = "select distinct motelabMoteID from " .
                           $_CONNECTDATATABLENAME .
                           " where motelabSeqNo >= " . $startIndex .
                           " and moteLabSeqNo <= " . $endIndex .
                           " and sourceaddr = " . $currentMote . 
                           " and seqno >= " . $startEpochIndex .
                           " and seqno <= " . $endEpochIndex;
  my $getMotesHeardStatement;
  $getMotesHeardStatement = $ourDB->prepare($getMotesHeardQuery)
    or die "Couldn't prepare query '$getMotesHeardQuery': $DBI::errstr\n";
  $getMotesHeardStatement->execute();
  while (my $getMotesHeardRef = 
            $getMotesHeardStatement->fetchrow_hashref()) {
    my $currentFromMote = $getMotesHeardRef->{'motelabMoteID'};
    my $getMoteDataQuery = "select count(*) as count, " .
                           " SUM(rssi) as rssi from " .
                           $_CONNECTDATATABLENAME . 
                           " where motelabSeqNo >= " . $startIndex .
                           " and moteLabSeqNo <= " . $endIndex .
                           " and sourceaddr = " . $currentMote . 
                           " and motelabMoteID = " . $currentFromMote .
                           " and seqno >= " . $startEpochIndex .
                           " and seqno <= " . $endEpochIndex;
    my $getMoteDataStatement;
    $getMoteDataStatement = $ourDB->prepare($getMoteDataQuery)
      or die "Couldn't prepare query '$getMoteDataQuery': $DBI::errstr\n";
    $getMoteDataStatement->execute();
    my $getMoteDataRef = $getMoteDataStatement->fetchrow_hashref();
    $rssiArray[$currentMote][$currentFromMote] = $getMoteDataRef->{'rssi'};
    $heardArray[$currentMote][$currentFromMote] = $getMoteDataRef->{'count'};
  }
}

my $selectGroupNumberQuery = "select groupno from auth.connectivity" .
                             " order by groupno desc limit 1";
my $selectGroupNumberStatement;
$selectGroupNumberStatement = $ourDB->prepare($selectGroupNumberQuery)
  or die "Couldn't prepare query '$selectGroupNumberQuery': $DBI::errstr\n";
$selectGroupNumberStatement->execute();
my $ourGroupID;
if ($selectGroupNumberStatement->rows == 0) {
  $ourGroupID = 0;
} else {
  my $selectGroupNumberRef = $selectGroupNumberStatement->fetchrow_hashref();
  $ourGroupID = $selectGroupNumberRef->{'groupno'} + 1;
}

# 31 Aug 2004: swies: Clear out old connectivity data
my $clearMoteConnectivityQuery = "update auth.motes set linkquality=\"\"";
my $clearMoteConnectivityStatement;
$clearMoteConnectivityStatement = 
    $ourDB->prepare($clearMoteConnectivityQuery) 
    or die "Couldn't prepare query '$clearMoteConnectivityQuery':" .
           "$DBI::errstr\n";
$clearMoteConnectivityStatement->execute();

for (my $i = 1; $i < @heardArray; $i++) {
  if ($heardArray[$i] == undef) {
    next;
  }
  my $entryString;
  my $skippedFirst = 0;
  for (my $j = 1; $j < @{$heardArray[$i]}; $j++) {
    if ($heardArray[$i][$j] != undef) {
      my $updateConnectivityQuery = "insert into auth.connectivity" .
                                    " set groupno=" . $ourGroupID .
                                    ", tomote=" . $j . 
                                    ", frommote=" . $i .
                                    ", num_samp=" . $sentArray[$i] .
                                    ", num_heard=" . $heardArray[$i][$j] .
                                    ", totrssi=" . $rssiArray[$i][$j];
      my $updateConnectivityStatement;
      $updateConnectivityStatement =
          $ourDB->prepare($updateConnectivityQuery)
        or die "Couldn't prepare query '$updateConnectivityQuery':" .
               "$DBI::errstr\n";
      $updateConnectivityStatement->execute();
      if ($skippedFirst) {
        $entryString .= "|";
      }
      $entryString .= sprintf("( %d, %f, %f )", $j, 
             $heardArray[$i][$j] / $sentArray[$i],
             $rssiArray[$i][$j] / $sentArray[$i]);
      $skippedFirst = 1;
    }
  }
  my $updateMoteConnectivityQuery = "update auth.motes set linkquality=\"" .
                                    $entryString . "\"" .
                                    " where moteid=" . $i;
  my $updateMoteConnectivityStatement;
  $updateMoteConnectivityStatement = 
      $ourDB->prepare($updateMoteConnectivityQuery) 
    or die "Couldn't prepare query '$updateMoteConnectivityQuery':" .
           "$DBI::errstr\n";
  $updateMoteConnectivityStatement->execute();
}

# 07 Sep 2004: swies: update our lastcontact time
my $lastContactQuery = "update auth.motes set lastcontact = now()" .
                                 " where linkquality <> ''";
my $lastContactStatement;
$lastContactStatement = 
    $ourDB->prepare($lastContactQuery) 
    or die "Couldn't prepare query '$lastContactQuery':" .
           "$DBI::errstr\n";
$lastContactStatement->execute();

$ourDB->do("drop table $_CONNECTDATATABLENAME");
$ourDB->do("drop table $_CONNECTCONTROLTABLENAME");
$ourDB->disconnect();

# Last, but not least, clean out the cache.
system("rm -f $_CONNECTCACHE/*");

# 14 Jul 2006 : GWA : Regenerate cached maps.
for (my $i = 1; $i <= 3; $i++) {
  my $getMapCommand = "wget -O $_CONNECTCACHE/$i.png $_MOTELABROOT/img/color-maps.php?floor=$i 2>/dev/null";
  system($getMapCommand);
  my $convertCommand = "convert -resize $_SMALLIMAGEX" . "x" . "$_SMALLIMAGEY $_CONNECTCACHE/$i.png $_CONNECTCACHE/$i-SMALL.jpg";
  system("$convertCommand");
  $convertCommand = "convert $_CONNECTCACHE/$i.png $_CONNECTCACHE/$i.jpg";
  system("$convertCommand");
}
