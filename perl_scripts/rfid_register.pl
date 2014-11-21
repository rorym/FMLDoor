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

logWrite("Waiting to register RFID Tag");

# Reading from Arduino via Serial
while (1) {
	my $rfid = $Arduino->receive();
	if (lookupRFID($rfid, $this_service) == 1) {
		logWrite("RFID: $rfid Authenticated");
		$Arduino->communicate('1');
	}else{
		logWrite("RFID: $rfid Failed Authentication");
		$Arduino->communicate('0');
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
			logWrite("Tag $rfid registered but not active");

		}else{
			logWrite("Tag $rfid already registered and active");
		}
	}else{
		logWrite("Registering Tag");
		if (registerTag($rfid, $service) > 0) {
			recordAccess($rfid, $service, 'register');
			logWrite("Registered Tag $rfid");
			return 1;
		}else{
			logWrite("Error Registering Tag");
		}
	}
	
	return 0;
}

sub registerTag {
	my $rfid = $_[0];
	
	my $query = "INSERT INTO makers (userid, rfid, username, display_name, active) VALUES (default, '$rfid', 'unallocated.tag', 'Unalocated Tag', '0');";

	my $execute = $connect->query($query);
	
	if ($connect->errno) {
		logWrite($connect->errmsg);
		return 0;
	}

	return 1;
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

        # Return true
        return 1;
}

