#!/usr/bin/perl

$motelab_user = "root";
$motelab_pass = "linhtinh";
$motelab_db = "auth";

$cmd = "mysql -h 192.168.72.58 -u $motelab_user -p$motelab_pass $motelab_db -B -s -e \"select moteid,roomlocation,jacknumber,ip_addr from motes;\"";

open(CMD, "$cmd|") || die "Cannot run $cmd\n";
while (<CMD>) {
  if (/(\d+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
    $moteid = $1; $roomloc = $2; $jacknumber = $3; $ipaddr = $4;
    print "MOTE: $moteid ROOM: $roomloc JACK: $jacknumber IP: $ipaddr\n";
    $moteid{$ipaddr} = $moteid;
    $jacknumber{$ipaddr} = $jacknumber;
    $roomlocation{$ipaddr} = $roomloc;
    $nodes{$roomloc} = $nodes{$roomloc} + 1;
  }
}
close(CMD);

$cmd = "nmap -sP 192.168.1.*";
open(CMD, "$cmd|") || die "Cannot run $cmd\n";
while ($line = <CMD>) {
  if ($line =~ /^Host\s+\(*([0-9\.]+)\)* appears to be up./) {
    $ipaddr = $1;
    if ($roomlocation{$ipaddr} eq "") {
      print "Node $1 is up (unknown room - not a registered connect?)\n";
      $unknowncount++;
    } else {
      print "Node $1 is up, room $roomlocation{$ipaddr}, jack $jacknumber{$ipaddr}\n";
      $connectcount++;
      $found{$ipaddr} = 1;
      $foundinroom{$roomlocation{$ipaddr}} = 
	$foundinroom{$roomlocation{$ipaddr}} + 1;
    }
  }
}

print "\n\n";

foreach $room (sort keys(%nodes)) {
  $connects = (int($nodes{$room}))/2;  # Each connect has two motes
  $found = int($foundinroom{$room});
  $down = $connects - $found;
  $downcount += $down;
  if ($down > 0) {
    print "Room $room has $down out of $connects nodes down";
    foreach $ipaddr (sort keys(%roomlocation)) {
      if (($roomlocation{$ipaddr} eq $room) && !$found{$ipaddr}) {
	print " [$jacknumber{$ipaddr}]";
      }
    }
    print "\n";
  }
}

print "Found $connectcount TMote Connects and $unknowncount unknown nodes.\n";
print "Total down nodes: $downcount\n";
