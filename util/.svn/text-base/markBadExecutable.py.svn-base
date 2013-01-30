#!/usr/bin/env python

import os, sys
from subprocess import (Popen, PIPE)

# Find files
p = Popen(r'find /local/motelab/www/users -path "*upload*" -name "*.exe" -printf "%p\n"', shell=True, stdout=PIPE)
(out, err) = p.communicate()
files = out.splitlines()
status = {}
for file in files:
  p = Popen("sudo /usr/local/bin/python /local/motelab/www/dev/util/testExecutable.py -v \"" + file + "\"", shell=True, stdout=PIPE)
  (out, err) = p.communicate()
  out = out.strip()
  (file, output) = out.split(" ", 1)
  print file,
  output = output.strip('"')
  if output != "TelosB" and output != "Compiled for TinyOS 1.x":
    print output
    p = Popen("mysql -u auth -pauth auth -B -e 'update files set isvalid=0, validstring=\"" + output + '" where path="' + file + "\" limit 1'", shell=True, stdout=PIPE)
    (out, err) = p.communicate()
  else:
    print output
