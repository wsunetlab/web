#!/usr/bin/perl
use DBI;
use strict;
use Thread;
use File::Path;

my $_DSN = "DBI:mysql:database=auth:host=netlab.encs.vancouver.wsu.edu:user=root:password=linhtinh";

my $ourDB = DBI->connect($_DSN)
  or die "Couldn't connect to database: $DBI::errstr\n";

my $nullPath;
my $nullProgOutput;
my $nullProgOutput2;
my $appProgOutput;
my $gatherDataOutput;
my $appPath;
my $gatherDataPath;


$appPath = "/opt/tinyos-2.x/apps/RadioCountToLeds";
$nullPath = "/opt/tinyos-2.x/apps/Null";
$gatherDataPath = "/var/www/web/daemon/hellomote";

print "Program Starts here\n";

my $moteQuery = "select moteid,ip_addr from auth.motes where active='1'";
my $moteStatement;
$moteStatement = $ourDB->prepare($moteQuery)
or die "Couldn't prepare query '$moteQuery': $DBI::errstr\n";

$moteStatement->execute();
#null Program Installation
while (my $moteRunRef = $moteStatement->fetchrow_hashref()) {
	chdir($nullPath) or die "cant chnge directory to null directory\n";
	#my $nullThread = new Thread(\&doProgram,$moteRunRef->{'moteid'},
	my $nullProgramCommand = "make telosb install.".$moteRunRef->{'moteid'}." bsl,".$moteRunRef->{'ip_addr'};
	$nullProgOutput .=`$nullProgramCommand`;
}
print "Null Prog output:$nullProgOutput\n";


$moteStatement->execute();
#Actual Program Installation

while (my $moteRunRef = $moteStatement->fetchrow_hashref()) {
	chdir($appPath) or die "cant chnge directory to app directory\n";
	#my $nullThread = new Thread(\&doProgram,$moteRunRef->{'moteid'},
	my $appProgramCommand = "make telosb install.".$moteRunRef->{'moteid'}." bsl,".$moteRunRef->{'ip_addr'};
	$appProgOutput .=`$appProgramCommand`;
}
#print "App Prog output:$appProgOutput\n";


$moteStatement->execute();
#Gather data here

my $gatherCommand = "./GatherData.pl ".$moteStatement->rows;
chdir($gatherDataPath) or die "Cant change directory while gatherting data\n";
$gatherDataOutput .= `$gatherCommand`;
sleep(30);
print "Gather Data Output:$gatherDataOutput\n";



$moteStatement->execute();
#Erase Motes At end 
while (my $moteRunRef = $moteStatement->fetchrow_hashref()) {
        chdir($nullPath) or die "cant chnge directory to null directory\n";
        #my $nullThread = new Thread(\&doProgram,$moteRunRef->{'moteid'},
        my $nullProgramCommand = "make telosb install.".$moteRunRef->{'moteid'}." bsl,".$moteRunRef->{'ip_addr'};
        $nullProgOutput2 .=`$nullProgramCommand`;
}
#print "Null Prog output:$nullProgOutput2\n";

#print "Output:$moteOutput\n";

#my $i;
#for($i=0;$i<2;$i++){

#chdir($nullPath) or die "cant chnge directory\n";
#my $nullProgramCommand = "make telosb install.".$i." bsl,"."/dev/ttyUSB".$i;
#print "Null program : $nullProgramCommand\n";
#$moteOutput .= `$nullProgramCommand`;
#}

#for($i=0;$i<2;$i++){

#chdir($appPath) or die "cant change directory\n";
#my $appProgramCommand = "make telosb install.".$i." bsl,"."/dev/ttyUSB".$i;
#print "App program : $appProgramCommand\n";
#$moteOutput .= `$appProgramCommand`;
#}

#for($i=0;$i<2;$i++){

#chdir($nullPath) or die "cant chnge directory\n";
#my $nullProgramCommand = "make telosb install.".$i." bsl,"."/dev/ttyUSB".$i;
#print "Null program : $nullProgramCommand\n";
#$moteOutput .= `$nullProgramCommand`;
#}

#}


