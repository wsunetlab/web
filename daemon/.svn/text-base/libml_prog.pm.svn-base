use strict;
use warnings;

require "sitespecific.pl";

our ($_JOBSCHEDULETABLENAME, $_DSN, $_JOBSTABLENAME,
$_JOBFILESTABLENAME, $_FILESTABLENAME, $_USERROOT,
$_MOTEINFOTABLENAME, $_SETMOTEID, $_AVROBJCOPY, $_TMPROOT, $_JAVAW,
$_REMOTEUISP, $_DBLOGGER, $_JAR, $_DBDUMPUSER, $_DBDUMPPASSWORD,
$_SESSIONTABLENAME, $_JOBDATAROOT, $_DATAUPDATEROOT, $_ZIP,
$_NODESTATUSTABLENAME,
$_PROGRAMMING_RETRIES, $_MAILTO, $_CHOWN, $_PROGRAMMING_TIME, $_CHGRP,
$_WEBUSER, $_JOBDAEMON, $_HAVEPOWERCOLLECT, $_POWERCOLLECTCMD,
$_EXTERNALSF, $_SFHOSTIPADDR, $_BLANK, $_MLPROGRAM, $_JOBPENDING,
$_JOBRUNNING, $_JOBFINISHED, $_JOBSTARTPROBLEM, $_JOBENDPROBLEM,
$_JOBPLEASEDELETE, $_MOTEREPROPORT, $_MOTECOMMPORT, $_MOTEPORTBASE,
$_DBLOGGERNAME, $_MLSF, $_ERASE, $_CHANGEBAUDRATE);

sub reprogramMotes($\@$$$$$) {
 
  my ($dbh, $moteProgram, $logFile, $owner, $getActive, $zoneID, $report) = @_;

  my $moteInfoStatement = getActiveMotes($dbh, $zoneID, $getActive);

  # 04 Apr 2006 : GWA : Due to issues with netbsl we're going to try and
  #               reprogram nodes one on a device at a time.

  my @moteInfoArray;
  my %moteMapping;
  my %IPSinUse;
  while (my $moteInfoRef = $moteInfoStatement->fetchrow_hashref()) {
    if (!exists($moteProgram->[$moteInfoRef->{'moteid'}])) {
      next;
    }
    my %tmpHash;
    $tmpHash{'moteid'} = $moteInfoRef->{'moteid'};
    $tmpHash{'program_host'} = $moteInfoRef->{'program_host'};
    $tmpHash{'program_port'} = $moteInfoRef->{'program_port'};
    $tmpHash{'programmed'} = 0;
    $moteMapping{$moteInfoRef->{'program_host'}}{$moteInfoRef->{'program_port'}}
    = $moteInfoRef->{'moteid'};
    push(@moteInfoArray, \%tmpHash);
    $IPSinUse{$moteInfoRef->{'program_host'}} = 0;
  }

  #
  # build up ml-program command line
  # 
  syslog("info", "FIRST $_MLPROGRAM -u $_REMOTEUISP >> $logFile 2>&1");
  open MLPROGRAM, "| $_MLPROGRAM -u $_REMOTEUISP >> $logFile 2>&1";
 
  # 04 Apr 2006 : GWA : Ugh...

  foreach my $currentMoteRef (@moteInfoArray) {
    #if ($IPSinUse{$currentMoteRef->{'program_host'}} == 1) {
    #  next;
    #} else {
    #  $IPSinUse{$currentMoteRef->{'program_host'}} = 1;
    #  $currentMoteRef->{'programmed'} = 1;
    #}
    my $moteid = $currentMoteRef->{'moteid'};
    my $binary = $moteProgram->[$moteid];
    my $moteAddress = $currentMoteRef->{'program_host'};
    my $motePort = $currentMoteRef->{'program_port'};
    syslog("info", "FIRST $moteAddress:$motePort:$binary\n");
    print MLPROGRAM "$moteAddress:$motePort:$binary\n";
    #`$_CHANGEBAUDRATE $moteAddress:$motePort`;
  }
  print MLPROGRAM "\n";
  close MLPROGRAM;

  #
  # parse log file for errors
  #
  my @ips;
  my $failureCount = 0;
  open MLPROGRAMLOG, "$logFile" or
    die "unable to open ml-program log file $logFile";
  while (my $line = <MLPROGRAMLOG>) {
    if ($line !~ /^([0-9\.]+)\s+(\d+)\s+(\S+( \S+)*)\s+$/) {
      next;
    }
    my $node = $1;
    my $port = $2;
    my $status =$3;
    chomp($status);
    my %tmpHash;
    $tmpHash{'nodeid'} = $moteMapping{$node}{$port};
    if ($status !~ /OK/) {
      $failureCount++;
      if ($status =~ /FAIL TCP/) {
        $tmpHash{'pingok'} = 0;
        $tmpHash{'programok'} = 0;
        $tmpHash{'disable'} = 1;
      } elsif ($status =~ /FAIL PROGRAM/) {
        $tmpHash{'pingok'} = 1;
        $tmpHash{'programok'} = 0;
        $tmpHash{'disable'} = 1;
      } elsif ($status =~ /FAIL HEADER/) {
        $tmpHash{'pingok'} = 1;
        $tmpHash{'programok'} = 0;
        $tmpHash{'disable'} = 0;
      }
    } else {
      $tmpHash{'pingok'} = 1;
      $tmpHash{'programok'} = 1;
    }
    push(@ips, \%tmpHash);
  }
  
  if(scalar @ips > 0) { 
    failedProgram($dbh, \@ips, $owner, $failureCount, $report);
  }
  
  syslog("info", "done programming motes");
}

###############################################################################

sub failedProgram($\@$$$) {
  my ($dbh, $ips, $owner, $failureCount, $report) = @_;

  my $OKCount = 0;
  my $NOPROGRAMCount = 0;
  my $NOPINGCount = 0;

  if ($failureCount > 0 && $report == 1) {
    syslog("info", "mailing $_MAILTO regarding:");
    open SENDMAIL, "| /usr/sbin/sendmail -t";
    print SENDMAIL qq{To: $owner\n};
    if ($owner ne $_MAILTO) {
      print SENDMAIL qq{Cc: $_MAILTO\n};
    }
    print SENDMAIL qq{From: motelab-admin\@motelab.eecs.harvard.edu\n};
    print SENDMAIL qq{Subject: $owner\'s MoteLab Job\n};
    print SENDMAIL qq{Content-type: text/plain\n\n};
    print SENDMAIL <<DONE;
This email was generated automatically.  Please DO NOT RESPOND.

While running your job there were problems reprogramming nodes:

DONE
  }
  foreach my $ip (@$ips) { 
   
    my $nodeID = $ip->{'nodeid'};
    my $pingOK = $ip->{'pingok'};
    my $programOK = $ip->{'programok'};
    my $disableOK = $ip->{'disable'};

    # 22 Mar 2005 : GWA : Disable mote so that it doesn't cause problems
    #               later.
   
    my $disableText = "";
    my $active = 1;
    if (!$pingOK) {
      $active = 0;
      $disableText = "Failed ping at " . localtime();
      $NOPINGCount++;
    } elsif (!$programOK) {
      $active = 0;
      $disableText = "Failed reprogramming at " . localtime();
      $NOPROGRAMCount++;
    } else {
      $disableText = "";
      $OKCount++;
    }
    if ($disableOK) { 
      my $disableQuery = qq{UPDATE $_SESSIONTABLENAME.$_MOTEINFOTABLENAME
                            SET active=$active,
                                notes="$disableText",
                                ping_ok=$pingOK,
                                erase_ok=$programOK,
                                status_timestamp=null
                                where moteid=$nodeID};
      my $disableStatement = $dbh->prepare($disableQuery);
      $disableStatement->execute();
      $disableQuery = qq{INSERT INTO $_SESSIONTABLENAME.$_NODESTATUSTABLENAME
                            SET ok=$active,
                                ping=$pingOK,
                                erase=$programOK,
                                removed=0,
                                changed=1,
                                node=$nodeID};
      $disableStatement = $dbh->prepare($disableQuery);
      $disableStatement->execute();
    }

    my $roomQuery = qq{SELECT roomlocation, ip_addr
                    FROM $_SESSIONTABLENAME.$_MOTEINFOTABLENAME
                    WHERE moteid=$nodeID};
    my $roomStatement = $dbh->prepare($roomQuery)
      or die "Couldn't prepare query '$roomQuery': $DBI::errstr\n";
    $roomStatement->execute();
    my @row = $roomStatement->fetchrow_array();
    if (!$active) {
      if (!$pingOK) {
        print SENDMAIL "PING\t";
      } elsif (!$programOK) {
        print SENDMAIL "PROGRAM\t";
      }
      print SENDMAIL "$nodeID\t$row[1]\t$row[0]\n";
      syslog("info", "node $row[1] at IP $nodeID in $row[0]\n");
    }
  }

  my $updateStatusLogQuery = qq{INSERT INTO $_SESSIONTABLENAME.health
                                SET okCount=$OKCount,
                                    noProgramCount=$NOPROGRAMCount,
                                    noPingCount=$NOPINGCount,
                                    timeTaken=NOW()};
  my $updateStatusLogStatement = $dbh->prepare($updateStatusLogQuery);
  $updateStatusLogStatement->execute();
 
  if ($failureCount > 0) {
    print SENDMAIL <<DONE;
Thank you for using MoteLab!

The MoteLab Team.
DONE
    close SENDMAIL;
  }
}

1;
