#!/usr/bin/perl

use strict;
use DBI;
use Device::SerialPort::Arduino;

# Database Credentials
my $dbuser = 'doorlock';
my $dbpass = 'ajr3afj34fa';

my $Arduino = Device::SerialPort::Arduino->new(
  port     => '/dev/ttyACM0',
  baudrate => 9600,
 
  databits => 8,
  parity   => 'none',
);

# Reading from Arduino via Serial
while (1) {
	my $rfid = $Arduino->receive();
	if (lookupRFID($rfid) == 1) {
		print "RFID: $rfid Authenticated\n";
		$Arduino->communicate('1');
		recordAccess($rfid, 1);
	}else{
		print "RFID: $rfid Failed Authentication\n";
		$Arduino->communicate('0');
		recordAccess($rfid, 0);
	}
}

# lookup the RFID Tag in the database
sub lookupRFID {
	my $rfid = $_[0];
	
	# Database Connection
	my $dbh = $DBI->connect('DBI::mysql::fml', $dbuser, $dbpass) || die "Could not connect to database: $DBI::errstr";

	# Database Query
	my $dbquery = "SELECT display_name FROM makers WHERE rfid='$rfid' AND active='1';";

	# prepare query
	my $sth = $dbh->prepare($dbquery);
	
	# execute query
	$sth->execute();
	
	my $rows = $sth->rows;
	
	$dbh->disconnect();
	
	# Check the results
	if ($rows > 0) {
		return 1;
	}else{
		return 0;
	}
}

# record access
sub recordAccess {
	my $rfid = $_[0];
	my $status = $_[1];
	
	# Database Connection
	my $dbh = $DBI->connect('DBI::mysql::fml', $dbuser, $dbpass) || die "Could not connect to database: $DBI::errstr";
	
	# Database Query
	my $dbquery = "INSERT INTO access_log (rfid, status, recordtime) VALUES ('$rfid', '$status', now());";
	
	$dbh->do($dbquery);
	
	$dbh->disconnect();
	
	return 1;
}
