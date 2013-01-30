#!/usr/bin/perl

$GetProcessId = `ps -ef | grep "java net.tinyos.tools.Listen" | awk '{print \$2}'  > processes.txt`; 

open FILE, "processes.txt" or die $!;

while($process_id = <FILE>){
	chomp($process_id);
	$killCommand = `sudo kill -9 $process_id`;
}
