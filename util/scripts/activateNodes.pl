#!/usr/bin/perl

$cmd = qq{mysql -u auth -pauth auth -B -s -e "select moteid,roomlocation,jacknumber,ip_addr from motes;"};

open(CMD, "$cmd |") || die "Cannot run $cmd\n";
while (<CMD>) {
  if (/(\d+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
    $ipaddr = $4;
    $found{$ipaddr} = 0;
  }
}
close(CMD);

$cmd = qq{nmap -sP 192.168.1.*};
open(CMD, "$cmd |") || die "Cannot run $cmd\n";
while (<CMD>) {
  if (/^Host\s+([0-9\.]+) appears to be up./) {
    $ipaddr = $1;
    if (defined($found{$ipaddr})) {
      $found{$ipaddr} = 1;
    }
  }
}

foreach $currentKey (keys(%found)) {
  print $currentKey . "\t" . $found{$currentKey} . "\n";
}
