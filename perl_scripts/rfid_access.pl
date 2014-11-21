#!/usr/bin/perl

use strict;
use Config::Simple;
use Device::SerialPort::Arduino;
use Mysql;
use Proc::Daemon;
use POSIX qw/strftime/;

# Run as a daemon / in the background
Proc::Daemon::Init;

# Config Variables
my $cfg = new Config::Simple('/etc/gatekeeper.cfg');
my $mysqlhost = $cfg->param('mysqlhost');
my $mysqluser = $cfg->param('mysqluser');
my $mysqlpass = $cfg->param('mysqlpass');
my $mysqldb = $cfg->param('mysqldb');
my $logfile = $cfg->param('logfile');

# Specify the service this rfid reader is for
my $this_service = $ARGV[0];

# Connect to MySQL
my $connect = Mysql->connect($mysqlhost, $mysqldb, $mysqluser, $mysqlpass);

# MySQL Error Handling
if ($connect->errno) {
        logWrite($connect->errmsg);
}

my $Arduino = Device::SerialPort::Arduino->new(
  port     => '/dev/ttyACM0',
  baudrate => 9600,
 
  databits => 8,
  parity   => 'none',
);

# Reading from Arduino via Serial
while (1) {
	my $serialData = $Arduino->receive();
	
	logWrite("Read $serialData from Arduino");
	
	if (length($serialData) > 6) {
		my $rfid = $serialData;

		if (lookupRFID($rfid, $this_service) == 1) {
			logWrite("RFID: $rfid Access to $this_service Granted");
			$Arduino->communicate('11111111') or die "ERROR: Failed to talk to Arduino";
		}else{
			logWrite("RFID: $rfid Failed Authentication");
			$Arduino->communicate('000000000') or die "ERROR: Failed to talk to Arduino";
		}
	}
}

# lookup the RFID Tag in the database
sub lookupRFID {
	my $rfid = $_[0];
	my $service = $_[1];
	
	# Database Query
	my $query = "SELECT userid, username, display_name, active FROM makers WHERE rfid='$rfid';";
	
	# Execute Query
	my $execute = $connect->query($query);
	
	# MySQL Error Handling
	if ($connect->errno) {
        	logWrite($connect->errmsg);
		return 0;
	}

	# If there are results process them
	if ($execute->numrows >= 1) {
        	my %qrows = $execute->fetchhash;

		my $userid = $qrows{'userid'};
		my $username = $qrows{'username'};
		my $display_name = $qrows{'display_name'};
		my $active = $qrows{'active'};
		
		if ($active < 1) {
			logWrite("User $userid is not active");
			recordAccess($rfid, $service, 'inactive');
		}
		
		recordAccess($rfid, $service, 'granted');
		
		return $active;
	}
}

# record access
sub recordAccess {
	my $rfid = $_[0];
	my $service = $_[1];
	my $status = $_[2];
	
	# Database Query
	my $query = "INSERT INTO access_log (rfid, status, service, recordtime) VALUES ('$rfid', '$status', '$service', now());";
	
	# Execute Query
	my $execute = $connect->query($query);
	
	# MySQL Error Handling
	if ($connect->errno) {
		logWrite($connect->errmsg);
		return 0;
	}
	
	return 1;
}

# logging Function
sub logWrite {
        # Get the message from input var
        my $message = $_[0];

        # Generate Time Stamp
        my $timestamp = strftime('%Y-%m-%d %H:%M:%S', localtime);

        # Write log
        system('echo "' . $timestamp . ' ' . $message . '" >> ' . $logfile);
	
	#print "$timestamp $message\n";

        # Return true
        return 1;
}

