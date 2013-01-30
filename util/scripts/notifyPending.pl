#!/usr/bin/perl

$cmd = "mysql -u auth -pauth auth -B -s -e \"select firstname,lastname,academicInstitution from pending;\"";

open(CMD, "$cmd|") || die "Cannot run $cmd\n";

$i = 0;
$waitingUsers = "";
while ($line = <CMD>) {
  $i++;
  $waitingUsers .= "\t" . $line;
}

if ($i == 0) {
  exit();
}

open(SENDMAIL, "| /usr/sbin/sendmail -oi -t");
$to = "To: motelab-admin\@eecs.harvard.edu\n";
$from = qq{From: motelab-admin\@eecs.harvard.edu\n};
$precedence = qq{Precedence: junk\n};
$xloop = qq{X-Loop: motelab-admin\@eecs.harvard.edu\n};
$subject = qq{Subject: MoteLab Account Requests Pending\n};
$content = <<OUT;
This is an automatically generated message. Please do not respond.

OUT

if ($i == 1) {
  $content .= <<OUT;
There is 1 MoteLab account request pending approval:

OUT
} else {
  $content .= <<OUT;
There are $i MoteLab account requests pending approval:

OUT
}
$content .= $waitingUsers;

$content .= <<OUT;

Please attend to them at your earliest convenience by visiting this page:

http://motelab.eecs.harvard.edu/user-create.php

Thanks.
OUT

print SENDMAIL $from;
print SENDMAIL $to;
print SENDMAIL $replyto;
print SENDMAIL $precedence;
print SENDMAIL $xloop;
print SENDMAIL $subject;
print SENDMAIL "Content-type:text/plain\n\n";
print SENDMAIL $content;
close(SENDMAIL);
