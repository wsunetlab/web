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
$_DBLOGGERNAME, $_OTHERBINROOT, $_MLSF, $_CSERIALFORWARDER,
$_ZONESTABLENAME, $_HARVARDBINROOT, $_STRIPLEDS);

sub getJobInfo($$) {
  my ($dbh, $jobid) = @_;
  my $basicQuery = qq{SELECT owner, 
                             name, 
                             powermanage, 
                             duringrun, 
                             disttype
                      FROM $_JOBSTABLENAME  
                      WHERE id=$jobid};
  my $basicStatement;
  $basicStatement = $dbh->prepare($basicQuery)
      or die "Couldn't prepare query '$basicStatement': $DBI::errstr\n";
  $basicStatement->execute();
  my $basicRef = $basicStatement->fetchrow_hashref();
  return $basicRef;
}

sub getJobDB($$) {
  my ($dbh, $jobOwner) = @_;
  my $moreBasicQuery = "select dbname from " . $_SESSIONTABLENAME .
                         " where username=\"" . $jobOwner . "\""; 
  my $moreBasicStatement;
  $moreBasicStatement = $dbh->prepare($moreBasicQuery)
    or die "Couldn't prepare `$moreBasicStatement': $DBI::errstr\n";
  $moreBasicStatement->execute();
  my $moreBasicRef = $moreBasicStatement->fetchrow_hashref();
  return $moreBasicRef->{'dbname'};
}

sub getMoteInfoTable($) {
  my $dbh = shift;
  my $moteBasicQuery = "select ip_addr, comm_port, sf_pid from " .
                       $_MOTEINFOTABLENAME .
                       " where active=1";
  my $moteBasicStatement;
  $moteBasicStatement = $dbh->prepare($moteBasicQuery)
    or die "Couldn't prepare query '$moteBasicQuery': $DBI::errstr\n";
  $moteBasicStatement->execute();
  return $moteBasicStatement;
}

sub updateSFPID($$$) {
  my ($dbh, $sfPID,$ip_addr) = @_;
  
  my $updateMotesQuery = "update motes set sf_pid=" . $sfPID .
                         " where ip_addr=\"" . $ip_addr .
                         "\"";
  my $updateMoteStatement;
  $updateMoteStatement = $dbh->prepare($updateMotesQuery);
  $updateMoteStatement->execute();
}

# 17 Jul 2006 : GWA : Changed to return an array of file information, rather
#               rather than a database reference, and to do assignment here.

sub getFilesInfo($\$\$) {
  my ($dbh, $pendingRef, $basicRef) = @_;
  my $jobID = $pendingRef->{'jobid'};
  my $zoneID = $pendingRef->{'zoneid'};
  my $distType = $basicRef->{'disttype'};
  my $motesProgram = $basicRef->{'motesprogram'};

  # 17 Jul 2006 : GWA : Get all motes for this zone.

  my $inZoneQuery = qq{SELECT motes 
                       FROM $_ZONESTABLENAME
                       WHERE id=$zoneID};
  my $inZoneStatement;
  $inZoneStatement = $dbh->prepare($inZoneQuery);
  $inZoneStatement->execute();
  my $inZoneRef = $inZoneStatement->fetchrow_hashref();
  my @zoneMotes = split(/\,/, $inZoneRef->{'motes'});
  my @inZoneMotes;

  # 17 Jul 2006 : GWA : It's actually OK to include motes that may be
  #               disabled here, as they will get filtered out later.

  foreach my $currentMote (@zoneMotes) {
    $inZoneMotes[$currentMote] = 1;
  }

  # 17 Jul 2006 : GWA : Get all executables for this file.
  
  my $programsQuery = qq{SELECT files.path, 
                                files.user, 
                                files.type, 
                                files.id,
                                jobfiles.moteid
                         FROM $_FILESTABLENAME, $_JOBFILESTABLENAME
                         WHERE jobfiles.jobid=$jobID
                               AND jobfiles.fileid = files.id
                               AND files.type="program"};
  my $programsStatement;
  $programsStatement = $dbh->prepare($programsQuery)
    or die "Couldn't prepare query '$programsStatement': $DBI::errstr\n";
  $programsStatement->execute();
  my %programFilesHash;
  my %motesFilesHash;

  # 17 Jul 2006 : GWA : For now we won't check here to make sure that people
  #               aren't assigning executables to motes that can't run them
  #               (i.e., in the wrong zone). However, in the future this will
  #               be important to do!

  while (my $programsRef = $programsStatement->fetchrow_hashref()) {
    my %tmpHash;
    $tmpHash{'path'} = $programsRef->{'path'};
    $tmpHash{'user'} = $programsRef->{'user'};
    $tmpHash{'type'} = $programsRef->{'type'};
    $motesFilesHash{$programsRef->{'moteid'}} = $programsRef->{'id'};
    $programFilesHash{$programsRef->{'id'}} = \%tmpHash;
  }

  # 17 Jul 2006 : GWA : We're going to start doing the binary->mote
  #               assignment here.  I'm hoping that this helps with a bunch
  #               of screwy cases in which motes going away and coming back
  #               would muss up the mote assignments. It should also be
  #               easier to deal with zone assignments here!

  my @returnArray;

  if ($distType eq "single") {

    # 17 Jul 2006 : GWA : Sanity check: should only have one executable!

    if (scalar(keys(%programFilesHash)) != 1) {
      die<<DONE;
INTERNAL ERROR: More than one executable file in a 'single' job!
DONE
    }
    
    my @files = keys(%programFilesHash);
    my $oneFileID = shift(@files);

    # 17 Jul 2006 : GWA : Do the assignment for this zone.

    foreach my $currentMote (@zoneMotes) {
      my %tmpHash;
      $tmpHash{'path'} = $programFilesHash{$oneFileID}{'path'};
      $tmpHash{'user'} = $programFilesHash{$oneFileID}{'user'};
      $tmpHash{'type'} = $programFilesHash{$oneFileID}{'type'};
      $tmpHash{'id'} = $oneFileID;
      $tmpHash{'moteid'} = $currentMote;
      push(@returnArray, \%tmpHash);
    }
  } elsif ($distType eq "even") {

    my $numFiles = scalar(keys(%programFilesHash));
    my @files = keys(%programFilesHash);

    my $fileIncrement = 0;
    foreach my $currentMote (@zoneMotes) {
      my %tmpHash;
      my $oneFileID = $files[$fileIncrement];
      $fileIncrement++;
      $fileIncrement %= $numFiles;
      $tmpHash{'path'} = $programFilesHash{$oneFileID}{'path'};
      $tmpHash{'user'} = $programFilesHash{$oneFileID}{'user'};
      $tmpHash{'type'} = $programFilesHash{$oneFileID}{'type'};
      $tmpHash{'id'} = $oneFileID;
      $tmpHash{'moteid'} = $currentMote;
      push(@returnArray, \%tmpHash);
    }
  } elsif ($distType eq "individual") {
    # 17 Jul 2006 : GWA : Do the assignment for this zone.

    foreach my $currentMote (@zoneMotes) {
      my %tmpHash;
      if (!defined($motesFilesHash{$currentMote})) {
        next;
      }
      my $oneFileID = $motesFilesHash{$currentMote};
      $tmpHash{'path'} = $programFilesHash{$oneFileID}{'path'};
      $tmpHash{'user'} = $programFilesHash{$oneFileID}{'user'};
      $tmpHash{'type'} = $programFilesHash{$oneFileID}{'type'};
      $tmpHash{'id'} = $oneFileID;
      $tmpHash{'moteid'} = $currentMote;
      push(@returnArray, \%tmpHash);
    }
  }

  # 17 Jul 2006 : GWA : Last get the class files.

  my $classQuery = qq{SELECT files.path, 
                                files.user, 
                                files.type, 
                                files.id
                         FROM $_FILESTABLENAME, $_JOBFILESTABLENAME
                         WHERE jobfiles.jobid=$jobID
                               AND jobfiles.fileid=files.id
                               AND files.type="class"};
  my $classStatement;
  $classStatement = $dbh->prepare($classQuery)
    or die "Couldn't prepare query '$classStatement': $DBI::errstr\n";
  $classStatement->execute();
  while (my $classRef = $classStatement->fetchrow_hashref()) {
    my %tmpHash;
    $tmpHash{'path'} = $classRef->{'path'};
    $tmpHash{'user'} = $classRef->{'user'};
    $tmpHash{'type'} = $classRef->{'type'};
    $tmpHash{'id'} = $classRef->{'id'};

    # 17 Jul 2006 : GWA : This is the moteid that identifies a class file.

    $tmpHash{'moteid'} = 0;
    push(@returnArray, \%tmpHash);
  }

  #foreach my $currentDebug (@returnArray) {
    #printf STDERR ("%s %s %s %d %d\n",
    #       $currentDebug->{'path'},
    #       $currentDebug->{'user'},
    #       $currentDebug->{'type'},
    #       $currentDebug->{'id'},
    #       $currentDebug->{'moteid'});
  #}
  return \@returnArray;
}

sub updateTempDir($$\$\$\$\$\$\$\$\$\$$) {
  my ($jobid, $id, $tdPathRef, $tdUserPathRef, $avrLogFileRef,
      $uispLogFileRef, $dblLogFileRef, $dblClassFileRef, $powerLogFileRef, 
      $mlProgramLogFileRef, $sfLogFileRef, $jobOwner) = @_;

  $$tdUserPathRef =qq{$jobOwner/jobs/job$jobid\_$id};
  $$tdPathRef = qq{$_USERROOT} . $$tdUserPathRef;

  $$avrLogFileRef = "$$tdPathRef/avr-objcopy.log";
  $$uispLogFileRef = "$$tdPathRef/remote-uisp.log";
  $$dblLogFileRef = "$$tdPathRef/DBLOGGER.ERRORS";
  $$dblClassFileRef = "$$tdPathRef/DBLOGGER.CLASSES";
  $$powerLogFileRef = "$$tdPathRef/powerManage.log";
  $$mlProgramLogFileRef = "$$tdPathRef/REPROGRAM.LOG";
  $$sfLogFileRef = "$$tdPathRef/sf.log";

  mkdir($$tdPathRef) unless -d $$tdPathRef;
  unless (-d $$tdPathRef) {
    die("couldn't create temp directory $$tdPathRef");
  }
}

sub handleClassFiles($\$\$\$$) {
  my($classRef,$classes,$classPaths,$classStringUpdate,$tempDirPath) = @_;
  
  # 03 Aug 2003 : GWA : Moteid == 0 means it should be a class file for
  #               messaging.  First, sanity checks.
  die("wrong file type for msg class") 
    unless $classRef->{type} eq "class";

  # 19 Aug 2003 : GWA : We need to figure out the actual correct name of
  #               the java class that we are trying to use.  To do this we
  #               run javaw on it and check the error message.
     
  my $javawError = `$_JCFDUMP $classRef->{path} 2>&1`;
  $javawError =~ /This class: ([A-Za-z\.\_]+), super/;
  my $javaClassName = $1;

  syslog("info", "registering %s", $javaClassName);

  # 03 Aug 2003 : GWA : The string $classes will hold a space seperated
  #               list of all the message class names to register.  The
  #               string $classPaths will hold a space seperated list of
  #               all the paths to the various classes, which we use to
  #               pass to jar.

  $$classes .= "$javaClassName $classRef->{'id'} ";
  my $javaClassPath = $javaClassName;
  $javaClassName =~ s/\./\//g;
  my @javaClassNameArray = split("/", $javaClassName);
  pop(@javaClassNameArray);
  my $javaFilePath = join("/", @javaClassNameArray);
  my $javaDirRoot = shift(@javaClassNameArray);

  syslog("info", "tempDirPath=%s, javaFilePath=%s, javaDirRoot=%s",
         $tempDirPath, $javaFilePath, $javaDirRoot);
  
  `mkdir -p $tempDirPath/jar/$javaFilePath`;
  `cp $classRef->{'path'} $tempDirPath/jar/$javaClassName.class`;

  $$classPaths .= " -C $tempDirPath/jar $javaClassName.class ";
  $$classStringUpdate .= "Added message class " .  
                        $javaClassPath . " with ID " .
                        $classRef->{'id'} . "\n";
 
}

sub cleanupExperimentFile($$) {
  my ($classRef, $tempDirPath) = @_;
  
  if ($classRef->{'moteid'} == 0) {
  } else {
    my $moteSREC = $tempDirPath . "/" . $classRef->{'moteid'} .  ".ihex";
    unlink($moteSREC);
    $moteSREC = $tempDirPath . "/" . $classRef->{'moteid'} . ".exe";
    unlink($moteSREC);
  }
}

sub handleMoteBinaries($\@\$$$) {
  my ($classRef, $programStringUpdate, $moteProgram, $tempDirPath,
      $avrLogFile) = @_;

  # 31 Aug 2003 : GWA : This is somewhat inefficient.  We do the
  #               conversion from .exe -> .srec here, and then change the
  #               moteID as well on the way to the temp directory.  It
  #               would be smarter to do all of the .exe -> .srec at once
  #               and then work from there, but oh well.

  syslog("info", "handling binary: path %s, id %d", $classRef->{'path'},
                 $classRef->{'moteid'});
      
  my $moteRoot = $tempDirPath . "/" . $classRef->{'moteid'};
  my $moteSREC1 = $moteRoot . ".ihex";
  #my $moteSREC2 = $moteRoot . ".ihex";
  $moteSREC1 = "\"" . $moteSREC1 . "\"";
  #$moteSREC2 = "\"" . $moteSREC2 . "\"";

  my $setMoteID = "PATH=\$PATH\:$_OTHERBINROOT $_SETMOTEID --objcopy msp430-objcopy --objdump msp430-objdump --target ihex  " . 
                  "\"$classRef->{'path'}\"" .
                  " $moteSREC1 TOS_LOCAL_ADDRESS=$classRef->{'moteid'}" .
                  " TOS_NODE_ID=$classRef->{'moteid'}" .
                  " ActiveMessageAddressC\\\$addr=$classRef->{'moteid'} 2>/dev/null 1>/dev/null";
  my $setMoteIdOutput = `$setMoteID`;
  #my $stripLeds = "PATH=\$PATH\:$_HARVARDBINROOT $_STRIPLEDS" .  
  #                " $moteSREC1 > $moteSREC2";
  #my $stripLedsOutput = `$stripLeds`;

  $moteProgram->[$classRef->{'moteid'}] = $moteSREC1;
  $programStringUpdate .= "Added program " .
                           $classRef->{'path'} . 
                           " for mote #" . 
                           $classRef->{'moteid'} . "\n";
}

sub markJobRunning($$$$$$) {
  my ($dbh, $dbLoggerPID, $tempDirUserPath, $basicRef,$pendingRef, $powerLoggerPID, $collecterPID) = @_;
    
  my $updateQuery = "UPDATE $_JOBSCHEDULETABLENAME SET 
                       state=$_JOBRUNNING, 
                       realstart=NOW(), pid=$dbLoggerPID, 
                       powerpid=$powerLoggerPID,
                       duringrunpid=$collecterPID,
                       jobtempdir=\"$tempDirUserPath\",
                       cacheddb=\"$basicRef->{'name'}" .  "_$pendingRef->{'id'}\", 
                       dbprefix=\"$basicRef->{'name'}_$pendingRef->{'id'}\" 
                     WHERE id=$pendingRef->{'id'}";
                     
  my $updateStatement;
  $updateStatement = $dbh->prepare($updateQuery) 
    or die "Couldn't prepare query '$updateStatement': $DBI::errstr\n";
  $updateStatement->execute();
}

sub markMissedJobs($) {

  my $dbh = shift;
  
  my $missedQuery = "select id, jobid, start, pid," .
                    " UNIX_TIMESTAMP(start) as unixstart," .
                    " UNIX_TIMESTAMP(end) as unixend from " . 
                    $_JOBSCHEDULETABLENAME . 
                    " where state=" . $_JOBPENDING . 
                    " and end <= NOW()" .
                    " and jobdaemon=\"" . $_JOBDAEMON . "\"";
  my $missedStatement;
  $missedStatement = $dbh->prepare($missedQuery)
    or die "Couldn't prepare query '$missedStatement': $DBI::errstr\n";
  $missedStatement->execute();


  # 18 Aug 2003 : GWA : Walk through all missed jobs marking them as problems.

  my $missedRef;
  while ($missedRef = $missedStatement->fetchrow_hashref()) {

    my $updateQuery = "update " .
                   $_JOBSCHEDULETABLENAME .
                   " set state=" . $_JOBSTARTPROBLEM .
                   " where id=" . $missedRef->{'id'};
    my $updateStatement;
    $updateStatement = $dbh->prepare($updateQuery)
      or die "Couldn't prepare query '$updateStatement': $DBI::errstr\n";
    $updateStatement->execute();

    syslog("warning", "missed job $missedRef->{'jobid'}\n");
  }
}

sub getActiveMotes($$$) {
  my ($dbh, $zoneID, $getActive) = @_;
  my $moteInfoQuery = qq{SELECT ip_addr, 
                                moteid, 
                                program_port, 
                                program_host 
                         FROM $_MOTEINFOTABLENAME};
  if ($getActive == 1) {
    $moteInfoQuery .= qq{ WHERE active=1};
  }
  my $moteInfoStatement;
  $moteInfoStatement = $dbh->prepare($moteInfoQuery) 
    or die "Couldn't prepare query `$moteInfoStatement': $DBI::errstr\n";
  $moteInfoStatement->execute();
  return $moteInfoStatement;
}

sub doMail($) {
  my $message = shift;

  open MAIL, "| mail -s \"motelab\" $_MAILTO";
  print MAIL $message;
  close MAIL;
}

sub startDuringRun($$$) {
  my $dbh = shift;
  my $command = shift;
  my $jobID = shift;
  my $jobJobID = shift;
  my $duringRunPID = fork();
  if ($duringRunPID == 0) {
    exec("exec " . $command . " > /dev/null 2> /dev/null");
  }
  my $updateDuringRunQuery = "UPDATE $_SESSIONTABLENAME.$_JOBSCHEDULETABLENAME " .
                            "SET duringrunpid=$duringRunPID " .
                            "WHERE id=$jobID";
  my $updateDuringRunStatement;
  $updateDuringRunStatement = $dbh->prepare($updateDuringRunQuery)
      or die "Couldn't prepare query '$updateDuringRunStatement': $DBI::errstr\n";
  $updateDuringRunStatement->execute();
}

sub startAfterRun {
}
1;
