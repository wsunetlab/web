#!/usr/bin/perl

# d is in degrees
# 0.0 <= p <= 1.0

#use strict;
  use DateTime;
  use POSIX qw(strftime);
  use DBI;
  use strict;

  my $_PMAX = 31; # TODO: Right now set to max - change if needed; min val:1 and max val:31
  my $_PMIN = 29;
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


  my $_DSN = "DBI:mysql:database=auth:host=netlab.encs.vancouver.wsu.edu:user=root:password=linhtinh";

  my $ourDB = DBI->connect($_DSN)
    or die "Couldn't connect to database: $DBI::errstr\n";

  my $packetAckQuery = "select rec_addr from auth.linkQuality where send_addr = $node and PRR > 0";
  my $packetAckStatement;

  my @Lu;

  if(@ARGV == 0 || @ARGV <=4){
    print "No Arguments found\n";
    print "usage: perl topologyConfig.pl nodeId stepperserial userNodelist jobId topologyId\n";
    exit(0);
  }


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
  my $d = 10;
  #just for testing
#  $d =20;
  my $bestD = $d;
  my $bestP = $p;

  chdir("/var/www/web/daemon") or die "$1";


 # my $_ROTATE = "/usr/lib/jvm/java-6-openjdk/bin/java -cp .:/var/www/web/daemon/phidget21.jar Rotate $stepperSerial";

# May 23 2013: phidget21.jar has been added to classpath, so no need to pass explicitly. 
  my $_ROTATE = "/usr/lib/jvm/java-6-openjdk/bin/java -cp .:/usr/lib/jvm/java-6-openjdk/lib/phidget21.jar Rotate $stepperSerial";
#my $_HELLO = "perl helloProgram.pl $node";

# TODO: You are suppose to send the power to get acknowledges by power. Modify the below _HELLO string to get the changes.
#my $_HELLO = "java hellomote.LoadPrograms $node";

#my $_HELLO = "/usr/lib/jvm/java-6-openjdk/bin/java -cp .:/var/www/web/daemon/mysql-connector-java-5.1.10-bin.jar hellomote.LoadPrograms";
# May 23 2013: Mysql.jar has been added to classpath, so no need to pass explicitly. 
#my $_HELLO = "/usr/lib/jvm/java-6-openjdk/bin/java hellomote.LoadPrograms";
#my $_HELLO = "perl LoadPrograms.pl";

  my $_HELLO = "/bin/bash envsetup.sh $jobID $topologyId";  

  #while (1) { #original loop
  my $i = 0;
  while($i < 3){
  chdir("/var/www/web/daemon") or die "$1";
  my $out1 = system("$_ROTATE $d");
  # wait for rotation to finish	
  sleep(5);

  @Lr = ();
  my $currentError = 0;
  
# TODO: send hello message and collect acks;

  chdir("/var/www/web/daemon/hellomote") or die "$1";
#TODO: make changes here for acknowledgment list
  my $ackList = `$_HELLO $p`;
  sleep(20);
#print "Ack List Output: $ackList\n";
  my @acks;
  $packetAckStatement = $ourDB->prepare($packetAckQuery)
   or die "Couldn't prepare query '$packetAckQuery': $DBI::errstr\n";
  $packetAckStatement->execute();
  while( my $packetAckRef = $packetAckStatement->fetchrow_hashref()){
    push(@acks,$packetAckRef->{'rec_addr'});
  }

#print "Acks:";
#print join(", ", @acks);
#print "\n";

#  my @acks = split(',', $ackList);

  foreach my $ack (@acks) { # for each acknowledgement
    push(@Lr, $ack); # add sender to Lr
    foreach my $element (@Lr) {
      if ("@Lu" !=~ /$element/) { # if Lu does not contain element
        $currentError++; # increment error
      }
    }

#print "Lr :";
#print join(", ", @Lr);
#print "\n";
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


  $d += $_DTHETA;

  $i++;
  } #while(1) loop ends here

# results:
#print "Best Degree D :$bestD\n";
#print "Best Tranmission Power P: $bestP\n";
#print "New Node List: @Lr\n";
#Aug 7 2013:trying to store everything in database instead of filee
=cut
  open (TOPDATA, ">>/var/www/web/daemon/hellomote/Topology_Result.summary");
#  print TOPDATA "$bestD\n";
  print TOPDATA "$bestP\n";
  print TOPDATA "$node".":"."@Lr\n";
  close TOPDATA;
=cut

#print "Lr Again:";
#print join(", ", @Lr);
#print "\n";
#convert perl array to perl string, check blog for reason
my $LrString = join " ", @Lr;

if($LrString eq ""){
	$LrString = 0;
}
  my $newTopDataQuery = "insert into auth.topology_jobdata (job_id,topology_id,lu_id,tx_power,new_nodes) values (".$jobID.",".$topologyId.",".$node.",".$bestP.",".$LrString.")";

print "Query: $newTopDataQuery\n";
  my $newTopDataStatement;

  $newTopDataStatement = $ourDB->prepare($newTopDataQuery)
   or die "Couldn't prepare query $newTopDataQuery: $DBI::errstr\n";
  $newTopDataStatement->execute();

#  $ourDB->disconnect;
