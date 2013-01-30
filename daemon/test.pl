use strict;

open(MYOUTFILE, ">>/var/www/web/daemon/output.txt");
print MYOUTFILE "Timestamp: "; #write text, no newline
print MYOUTFILE "\n";
print "Timestamp: "; #write text, no newline
print "\n";
close(MYOUTFILE);
