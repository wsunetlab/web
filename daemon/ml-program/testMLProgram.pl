#!/usr/bin/perl

use strict;
use File::Temp qw/ tempfile tempdir /;

my $maxConcurrent = 1000;
my $mlProgram = $ARGV[0];
my $binary = $ARGV[1];
my $netBSL = $ARGV[2];
my $counter = $ARGV[3];
my $OK = 0;
my $NOPING = 0;
my $NOPROGRAM = 0;

my $motesCommand = qq{mysql -u root -plinhtinh auth -B -e "select program_host, program_port from motes"};
#my $motesCommand = qq{mysql -u auth -pauth auth -B -e "select program_host, program_port from motes where moteid>=91 and moteid<=102"};
my $motesOutput = `$motesCommand`;
my @motesOutput = split(/\n+/, $motesOutput);

my ($unused, $temporaryFile) = tempfile();
my $startTime = time();
my @moteInfoArray;

foreach my $currentMote(@motesOutput) {
  if ($currentMote !~ /([0-9\.]+)\s+(\d+)/) {
    next;
  }
  my %tmpHash;
  $tmpHash{'programHost'} = $1;
  $tmpHash{'programPort'} = $2;
  push(@moteInfoArray, \%tmpHash);
}

TOP:
open(MLPROGRAM, "| $mlProgram -u $netBSL > $temporaryFile 2>&1");
#open(MLPROGRAM, "| $mlProgram -v -u $netBSL > $temporaryFile 2>&1");

my %currentProgramHash;
my $firstHost;

for (my $i = 0; $i < $maxConcurrent;) {
  if (scalar(@moteInfoArray) == 0) {
    goto DONE;
  }
  my $tmpHash = shift(@moteInfoArray);
  
  my $uniqString = $tmpHash->{'programHost'} . $tmpHash->{'programPort'};

  if (defined($firstHost)) {
    if ($uniqString eq $firstHost) {
      unshift(@moteInfoArray, $tmpHash);
      goto DONE;
    }
  }

  if ($currentProgramHash{$tmpHash->{'programHost'}} == 1) {
    push(@moteInfoArray, $tmpHash);
    if (!(defined($firstHost))) {
      $firstHost = $uniqString;
    }
    next;
  }
  $currentProgramHash{$tmpHash->{'programHost'}} = 1;
  my $host = $tmpHash->{'programHost'};
  my $port = $tmpHash->{'programPort'};
  $i++;
  print MLPROGRAM "$host:$port:$binary\n";
}
DONE:
print MLPROGRAM "\n";
close MLPROGRAM;

my $summaryLine = `cat $temporaryFile | grep -P ^SUMMARY`;
chomp($summaryLine);
$summaryLine =~ /OK (\d+), NOPING (\d+), NOPROGRAM (\d+)/;
$OK += $1;
$NOPING += $2;
$NOPROGRAM += $3;

print `cat $temporaryFile | grep -v -P ^SUMMARY`;

if (scalar(@moteInfoArray) > 0) {
  undef(%currentProgramHash);
  undef($firstHost);
  goto TOP;
}

my $timeDiff = time() - $startTime;
print "$counter SUMMARY: OK $OK, NOPING $NOPING, NOPROGRAM $NOPROGRAM\n";
print "Operation took $timeDiff seconds\n";
