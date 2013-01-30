#!/usr/bin/env python

import sys, signal, re
from optparse import OptionParser

from subprocess import Popen
from subprocess import PIPE

AVR_OBJDUMP='avr-objdump'
AVR_OBJCOPY='avr-objcopy'

MSP430_OBJDUMP='msp430-objdump'
MSP430_OBJCOPY='msp430-objcopy'

def subprocess(cmd, timeout=0):
    def setupAlarm():
        signal.signal(signal.SIGALRM, alarmHandler)
        signal.alarm(timeout)

    def alarmHandler(signum, frame):
        sys.exit(1)

    proc = Popen(cmd, preexec_fn=setupAlarm, stdout=PIPE, stderr=PIPE)
    (out, err) = proc.communicate()
    return (out, err, proc.returncode)

def getElfFileType(exeFile):
    """
    returns a tuple consisting of the mote platofrm, TinyOS version (1 or 2),
    and a flag that is True if the binary is built to be installed with TOSBoot.
    """
    (out, err, ret) = subprocess([MSP430_OBJDUMP, '-t', exeFile])
    if ret == 0:
        if re.search(r'TOSH_queue', out):
            return (False, "Compiled for TinyOS 1.x")
        elif re.search(r'SchedulerBasicP', out):
            pass
        else:
            return (False, "Unknown OS")

        (out, err, ret) = subprocess([MSP430_OBJDUMP, '-f', exeFile])
        if ret == 0:
            if re.search(r'elf32-msp430', out):
                if re.search(r'start address 0x00004800', out):
                    return (True, "TelosB")
                elif re.search(r'start address 0x00004000', out):
                    return (True, "TelosB")
                else:
                    return (False, "Not a TMote Sky executable")

    return (False, "Not a TMote Sky executable")

def main():
    parser = OptionParser()
    parser.add_option("-n", "--name", action="store_true", dest="printname", help="Print name along with output.")
    parser.add_option("-p", "--printall", action="store_true", dest="printall", help="Print correct and erroneous binaries.")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose", help="Verbose output.")
    parser.set_defaults(printname=False, printall=False)
    (options, args) = parser.parse_args()

    if len(args) < 1:
      print "No files provided"
      sys.exit(-1)
    for arg in args:
      (OK, error) = getElfFileType(arg)
      if OK and options.printname and options.printall:
        print arg
      if OK and options.verbose:
        print arg, '"' + error + '"'
      elif not OK:
        if options.printname or options.verbose:
          print arg, '"' + error + '"'
        else:
          print error

if __name__ == "__main__":
    main()
