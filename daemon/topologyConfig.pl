#!/usr/bin/perl

# d is in degrees
# 0.0 <= p <= 1.0

#use strict;

my $_PMAX = 31; # TODO: change if needed
my $_PMIN = 1;
my $_PDELTA = 1;

my $_DMAX = 90;
my $_DTHETA = 20;

my $node = $ARGV[0];
my $stepperSerial = $ARGV[1];
my $userNodeList = $ARGV[2];

my @Lu;
#my $Lu;
print " coming in topologyconfig.pl \n";
if (defined($userNodeList)) {
  @Lu = split(',', $userNodeList);
  print "Lu Size:", scalar @Lu ,"\n";
} else {
  @Lu = (); # user wants this node to connect to no other nodes
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
# to get current directory
use Cwd qw();
my $path = Cwd::cwd();
print "Current directory:$path\n";
#

my $_ROTATE = "/usr/lib/jvm/java-6-openjdk/bin/java -cp .:/var/www/web/daemon/phidget21.jar Rotate $stepperSerial";
#my $_HELLO = "perl helloProgram.pl $node";
# TODO: You are suppose to send the power to get acknowledges by power. Modify the below _HELLO string to get the changes.
my $_HELLO = "java hellomote.LoadPrograms $node";
#while (1) {
$i = 0;
while($i <= 2){
#  print "$_ROTATE $d";
  print "Applied Degree : $d\n";
	my $out1 = system("$_ROTATE $d");
	
#  my $out = system("$_ROTATE");
 print "Java output:$out1\n";
#  print `$_ROTATE $d\n`;
sleep(10);
  print "done rotating\n";
  @Lr = ();
  my $currentError = 0;
  # TODO: send hello message and collect acks;
  #  while (0) {
# Run Hello world ack code 
my $ackList = `$_HELLO $p`;
  
#  sleep(10);
  
=for comment
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
  }


  if ($bestError == 0 || $d == $_DMAX) {
    if ($p != $_PMIN) {
      $p -= $_PDELTA;
      $d = 0;
      next; # continue;
    } else {
      last; # break;
    }
  }
=cut

 # }

  $d += $_DTHETA;
  print "New Degree d: $d \n";
 # sleep(0);
$i++;
}

# results:
print "Best Degree D :$bestD\n";
print "Best Tranmission Power P: $bestP\n";
print "New Node List: @Lr\n";
