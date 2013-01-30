#!/usr/bin/perl

use strict;
use File::Temp qw/ tempfile tempdir unlink0 /;

# 26 Apr 2004 : GWA : Probably don't need all of these.

our ($_JOBSCHEDULETABLENAME,
    $_CONNECTDSN,
    $_JOBSTABLENAME,
    $_JOBFILESTABLENAME,
    $_FILESTABLENAME,
    $_USERROOT,
    $_MOTEINFOTABLENAME,
    $_SETMOTEID,
    $_AVROBJCOPY,
    $_TMPROOT,
    $_JAVAW,
    $_REMOTEUISP,
    $_DBLOGGER,
    $_JAR,
    $_DBDUMPUSER,
    $_DBDUMPPASSWORD,
    $_SESSIONTABLENAME,
    $_JOBDATAROOT,
    $_DATAUPDATEROOT,
    $_ZIP,
    $_CHOWN,
    $_CHGRP,
    $_WEBUSER,
    $_JOBDAEMON,
    $_HAVEPOWERCOLLECT,
    $_POWERCOLLECTCMD,
    $_EXTERNALSF,
    $_SFHOSTIPADDR,
    $_JCFDUMP,
    $_DBLOGGERPATH,
    $_JAVA);

require "sitespecific.pl";

if (@ARGV < 1) {
  print "usage: testClassFile.pl <classFile>\n";
  exit(-1);
}
my ($fh, $filename) = tempfile(SUFFIX => '.class', CLEANUP => 1);
`cp $ARGV[0] $filename`;

my $javawError = `$_JCFDUMP $filename 2>&1`;
my $origJavawError = $javawError;
$javawError =~ /This class: ([A-Za-z\.]+), super/;
my $javaClassName = $1;

if ($javaClassName eq "") {
  print "Not a valid Java .class file.\n";
  unlink($filename);
  exit(-1);
}

my $javaClassPath = $javaClassName;
$javaClassName =~ s/\./\//g;
my @javaClassNameArray = split("/", $javaClassName);
pop(@javaClassNameArray);
my $javaFilePath = join("/", @javaClassNameArray);
my $javaDirRoot = shift(@javaClassNameArray);

my $dir = tempdir( CLEANUP => 1 );
`mkdir -p $dir/jar/$javaFilePath`;
`cp $filename $dir/jar/$javaClassName.class`;
`cp $_DBLOGGERPATH $dir/`;
`$_JAR uf $dir/dbDump.jar -C $dir/jar/ $javaClassName.class`;
my $dbLoggerCommand = "$_JAVA -jar $dir/dbDump.jar" .
                      " --classes $javaClassPath 1" .
                      " --testOnly";
my $output = `$dbLoggerCommand 2>&1`;
if ($output ne "") {
  print "$output\n";
  unlink($filename);
  `rm -rf $dir`;
  exit(-1);
}
unlink($filename);
`rm -rf $dir`;
exit(0);
