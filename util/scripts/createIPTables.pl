#!/usr/bin/perl

use strict;

my $motelabUser = "auth";
my $motelabPassword = "auth";
my $motelabDB = "auth";

my $DBCommand = qq{mysql -u $motelabUser -p$motelabPassword $motelabDB -B -s -e "select distinct(ip_addr) from motes order by ip_addr";};

open(CMD, "$DBCommand |") 
  or die "Cannot run $DBCommand\n";

my %IPAddr;

while (my $line = <CMD>) {
  if ($line =~ /([0-9\.]+)/) {
    $IPAddr{$1} = 1;
  }
}

# 03 Mar 2006 : GWA : Flush old rules.

`/sbin/iptables -t nat -F`;

# 03 Mar 2006 : GWA : General postrouting

foreach my $currentIPAddr (sort(keys(%IPAddr))) {
  `/sbin/iptables -t nat -A POSTROUTING -d $currentIPAddr -j SNAT --to 192.168.1.1`;
}

# 03 Mar 2006 : GWA : Node status pages

my $startStatusPort = 10000;
foreach my $currentIPAddr (sort(keys(%IPAddr))) {
  `/sbin/iptables -t nat -A PREROUTING -p tcp -i eth1 -d 140.247.62.118 --dport $startStatusPort -j DNAT --to $currentIPAddr:80`;
  $startStatusPort++;
}

# 03 Mar 2006 : GWA : Node data ports.

my $DBCommand = qq{mysql -u $motelabUser -p$motelabPassword $motelabDB -B -s -e "select moteid,ip_addr,comm_port from motes order by moteid";};

open(CMD, "$DBCommand |") 
  or die "Cannot run $DBCommand\n";

my %Motes;
my %Ports;

while (my $line = <CMD>) {
  if ($line =~ /([0-9]+)\s+([0-9\.]+)\s+([0-9]+)/) {
    $Motes{$1} = $2;
    $Ports{$1} = $3;
  }
}

foreach my $currentMote (sort {$a <=> $b} (keys(%Motes))) {
  my $nodeDataPort = $Ports{$currentMote};
  my $nodeIPAddr = $Motes{$currentMote};
  my $nodeDPort = 20000 + $currentMote;
  `/sbin/iptables -t nat -A PREROUTING -p tcp -i eth1 -d 140.247.62.118 --dport $nodeDPort -j DNAT --to $nodeIPAddr:$nodeDataPort`;
}

# 03 Mar 2006 : GWA : Save rules.
`/sbin/iptables-save > /etc/sysconfig/iptables`;

# 03 Mar 2006 : GWA : List rules.
my $newRules = `/sbin/iptables -t nat -L`;
print "$newRules";
