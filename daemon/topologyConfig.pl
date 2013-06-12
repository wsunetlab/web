#!/usr/bin/perl

# d is in degrees
# 0.0 <= p <= 1.0

#use strict;
  use DateTime;
  use POSIX qw(strftime);

  my $_PMAX = 5; # TODO: Right now set to max - change if needed; min val:1 and max val:31
  my $_PMIN = 1;
  my $_PDELTA = 1;

  my $_DMAX = 90;
  my $_DTHETA = 20;

#Arguments Start
  my $node = $ARGV[0];
  my $stepperSerial = $ARGV[1];
  my $userNodeList = $ARGV[2];

  my $jobID = $ARGV[3];
  my $topologyId = $ARGV[4];
#Arguments End


  my @Lu;

  if(@ARGV == 0 || @ARGV <=4){
    print "No Arguments found\n";
    print "usage: perl topologyConfig.pl nodeId stepperserial userNodelist jobId topologyId\n";
    exit(0);
  }

#my $Lu;

#print "File started Here (TopologyConfig.pl), Time of Start:";
#print strftime("%a, %d %b %Y %H:%M:%S %z", localtime(time())) . "\n";
#print "\n";

  if (defined($userNodeList)) {
    @Lu = split(',', $userNodeList);
   # print "Lu Size:", scalar @Lu ,"\n";
  } else {
    @Lu = (); # user wants this node to connect to no other nodes
  }

  foreach my $val (@Lu) {
   # print "$val\n";
  }

  my $p = $_PMAX;
  my @Lr;
  my $bestError = $#Lu;
  my $d = 0;
  #just for testing
  $d =20;
  my $bestD = $d;
  my $bestP = $p;

  chdir("/var/www/web/daemon") or die "$1";


  my $_ROTATE = "/usr/lib/jvm/java-6-openjdk/bin/java -cp .:/var/www/web/daemon/phidget21.jar Rotate $stepperSerial";

# May 23 2013: phidget21.jar has been added to classpath, so no need to pass explicitly. 
#my $_ROTATE = "/usr/lib/jvm/java-6-openjdk/bin/java Rotate $stepperSerial";
#my $_HELLO = "perl helloProgram.pl $node";

# TODO: You are suppose to send the power to get acknowledges by power. Modify the below _HELLO string to get the changes.
#my $_HELLO = "java hellomote.LoadPrograms $node";

#my $_HELLO = "/usr/lib/jvm/java-6-openjdk/bin/java -cp .:/var/www/web/daemon/mysql-connector-java-5.1.10-bin.jar hellomote.LoadPrograms";
# May 23 2013: Mysql.jar has been added to classpath, so no need to pass explicitly. 
#my $_HELLO = "/usr/lib/jvm/java-6-openjdk/bin/java hellomote.LoadPrograms";
#my $_HELLO = "perl LoadPrograms.pl";

  my $_HELLO = "/bin/bash envsetup.sh $jobID $topologyId";  

  #while (1) { #original loop
  $i = 0;
  while($i <= 1){
  #  print "$_ROTATE $d";
  #  print "Applied Degree : $d\n";
  chdir("/var/www/web/daemon") or die "$1";
  my $out1 = system("$_ROTATE $d");
  # wait for rotation to finish	
  sleep(5);

#  my $out = system("$_ROTATE");
# print "Java output:$out1\n";
#  print `$_ROTATE $d\n`;
#  print "done rotating\n";

  @Lr = ();
  my $currentError = 0;
  
# TODO: send hello message and collect acks;
  #  while (0) {
# Run Hello world ack code 
#my $ackList = `$_HELLO $p`;

  chdir("/var/www/web/daemon/hellomote") or die "$1";
#TODO: make changes here for acknowledgment list
  my $ackList = `$_HELLO $p`;

  sleep(20);
#print "Ack List Output: $ackList\n";
#my $ackList = `$_HELLO $p`;  
#  sleep(80);
#print $ackList;
  

  my @acks = split(',', $ackList);

  foreach my $ack (@acks) { # for each acknowledgement
    push(@Lr, $ack); # add sender to Lr
    foreach my $element (@Lr) {
      if ("@Lu" !=~ /$element/) { # if Lu does not contain element
        $currentError++; # increment error
      }
    }

    if ($currentError < $bestError ||
        ($currentError == $bestError && $p < $bestP)) {
      $bestError = $currentError;
      $bestD = $d;
      $bestP = $p;
    }
  }  #for each ack loop ends


  if ($bestError == 0 || $d == $_DMAX) {
    if ($p != $_PMIN) {
      $p -= $_PDELTA;
      $d = 0;
      next; # continue;
    } else {
      last; # break;
    }
  }


 # }

  $d += $_DTHETA;
 # print "New Degree d: $d \n";
 # sleep(0);

  $i++;
  } #while(1) loop ends here

# results:
#print "Best Degree D :$bestD\n";
#print "Best Tranmission Power P: $bestP\n";
#print "New Node List: @Lr\n";

  open (TOPDATA, ">/var/www/web/daemon/hellomote/Topology_Result.summary");
  print TOPDATA "$bestD\n";
  print TOPDATA "$bestP\n";
  print TOPDATA "@Lr\n";
  close TOPDATA;

#print "End time:";
#print DateTime->now()->strftime("%a, %d %b %Y %H:%M:%S %z");
#print strftime("%a, %d %b %Y %H:%M:%S %z", localtime(time())) . "\n";
#print "\n";
