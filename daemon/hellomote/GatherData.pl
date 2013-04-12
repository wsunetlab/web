#!/usr/bin/perl
use DBI;
use strict;
use Thread;
use File::Path;

my $_DSN = "DBI:mysql:database=auth:host=netlab.encs.vancouver.wsu.edu:user=root:password=linhtinh";

my $ourDB = DBI->connect($_DSN)
  or die "Couldn't connect to database: $DBI::errstr\n";

my $numMotes = $ARGV[0];

my $moteListRoot = "select moteid,ip_addr from auth.motes where active='1'";
my $moteListStatement;
$moteListStatement = $ourDB->prepare($moteListRoot)
	or die "Couldn't prepare query '$moteListStatement': $DBI::errstr\n";
$moteListStatement->execute();

while(my $moteListRef = $moteListStatement->fetchrow_hashref()){
#for($i = 0; $i < $numMotes; $i++){
my $commandString;
my $run_result;
	$commandString = "java net.tinyos.tools.Listen -comm serial@".$moteListRef->{'ip_addr'}.":telos > USB".$moteListRef->{'moteid'}."Data.txt &";
	$run_result = `$commandString`;
	#print "$commandString\n";
#}
}
sleep(10);

my $GetProcessId = `ps -ef | grep "java net.tinyos.tools.Listen" | awk '{print \$2}'  > processes.txt`;
my $process_id;
open FILE, "processes.txt" or die $!;

while($process_id = <FILE>){
        chomp($process_id);
        my $killCommand = `kill -9 $process_id`;
}

my $AnalyzeConnectivity;
my $run_analyze;
chdir('/var/www/web/daemon/') or die "$!";
$AnalyzeConnectivity = "java hellomote.AnalyzeConnectivity";
$run_analyze = `$AnalyzeConnectivity`;
print "$run_analyze\n";
#sleep(40);
