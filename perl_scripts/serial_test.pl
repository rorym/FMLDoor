#!/usr/bin/perl

use strict;
use Device::SerialPort::Arduino;

my $Arduino = Device::SerialPort::Arduino->new(
  port     => '/dev/ttyACM0',
  baudrate => 9600,
 
  databits => 8,
  parity   => 'none',
);

my $outdata = $ARGV[0];

print "Sending $outdata to Arduino\n\n";

# Reading from Arduino via Serial
while (1) {
	my $indata = $Arduino->receive();
	print $indata;
	print "\n";
	$Arduino->communicate($outdata);
}

