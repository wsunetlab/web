#!/usr/bin/perl

# d is in degrees
# 0.0 <= p <= 1.0

use strict;

my $_PMAX = 31; # TODO: change if needed
my $_PMIN = 1;
my $_PDELTA = 1;

my $_DMAX = 90;
my $_DTHETA = 10;

my $node = $ARGV[0];
my $stepperSerial = $ARGV[1];
my $userNodeList = $ARGV[2];

my @Lu;
if (defined($userNodeList)) {
  @Lu = split(',', $userNodeList);
} else {
  @Lu = (); # user wants this node to connect to no other nodes
}

my $p = $_PMAX;
my @Lr;
my $bestError = $#Lu;
my $d = 0;
my $bestD = $d;
my $bestP = $p;

my $_ROTATE = "java -cp .:phidget21.jar Rotate $stepperSerial";
#my $_HELLO = "perl helloProgram.pl $node";
# TODO: You are suppose to send the power to get acknowledges by power. Modify the below _HELLO string to get the changes.
my $_HELLO = "java hellomote.LoadPrograms $node";
while (1) {
  print "$_ROTATE $d";
  print `$_ROTATE $d`;
  print "done rotating";
  @Lr = ();
  my $currentError = 0;
  # TODO: send hello message and collect acks;
#  while (0) {
  my $ackList = `$_HELLO $p`;
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
 # }
  $d += $_DTHETA;
 # sleep(0);
}

# results:
print $bestD;
print $bestP;
print "@Lr";
