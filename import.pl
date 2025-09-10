#!/usr/bin/perl

############################################################################################################
#
# Use import.pl to import the MaxMind GeoLite2-Country-CSV file into your MySQL database
#
############################################################################################################

use strict;
use FindBin '$RealBin';
use lib $RealBin;
use DBI;
use Cwd 'abs_path';
use File::Basename;
use Net::CIDR;
use File::Spec;
use Log::Rolling;


my %config;
&get_configuration;

### Let's put configuration into easier to use variables

### Database configuration variables
my $db_name = $config{db_name};
my $db_username = $config{db_username};
my $db_password = $config{db_password};
my $mysql_hostname = $config{mysql_hostname};
my $mysql_port = $config{mysql_port};

### Other configuration variables
my $maxmind_account_id = $config{maxmind_account_id};
my $maxmind_license_key = $config{maxmind_license_key};
my $maxmind_permalink = $config{maxmind_permalink};
my $wget_path = $config{wget_path};
my $unzip_path = $config{unzip_path};

### Other global variables
my $debug = "N"; ### Y/N - Enable/Disable debug messages
my $delete_downloaded_files = "N"; ### Y/N - Leave or delete downloaded files

### Get full server path to script/data directories
my $full_path = abs_path($0);
my $script_dir  = dirname($full_path);
my $data_directory = "$script_dir/data";

# Record the start time
my $start = time();



################################################################################################
### Download GeoLite Country CSV files and import it into Database
################################################################################################
print "=============================================================================\n";
if ($ARGV[0] eq "-update") 
{
	&update_maxmind_country_csv;
}
elsif ($ARGV[0] eq "-import") ### Only Import GeoLite Country CSV files into Database (For testing/debugging purposes)
{
	&doimport;
}
else
{
	&display_help;
}
print "=============================================================================\n";
################################################################################################
################################################################################################
################################################################################################


# Record the end time
my $end = time();
	# Calculate elapsed time
	my $elapsed = $end - $start;
	# Convert to minutes and seconds
	my $minutes = int($elapsed / 60);
	my $seconds = $elapsed % 60;
print "Execution time: $minutes minute(s) and $seconds second(s)\n";








sub doimport
{

my ($dsn, $dbh, $sth);



# Connect to MySQL
if ($mysql_hostname eq ""){$dsn = "DBI:mysql:$db_name";} else {$dsn = "DBI:mysql:$db_name:$mysql_hostname:$mysql_port";}
$dbh = DBI->connect($dsn, $db_username, $db_password);
if ( !defined $dbh ) { die "Cannot connect to MySQL server: $DBI::errstr\n" . "Check that the databse name, database user name or database password is correct in config.cfg"; } 

	my $sql = "DROP TABLE IF EXISTS world_ip_resolver_TMP";
		$sth = $dbh->prepare($sql);
		$sth->execute;
	my $serror = $sth->errstr; if ($serror ne "") { die "SQL Syntax Error: $serror - From: $sql"; }  	 


print "Creating world_ip_resolver_TMP table (temporary table) for import... \n";

$sql = "CREATE TABLE world_ip_resolver_TMP
						(
						startip				varchar(16),
						endip				varchar(16),

						startnum			BIGINT,
						endnum				BIGINT,
						countrycode			varchar(2),
						country				varchar(255),

						INDEX (startnum), 
						INDEX (endnum),
						INDEX (countrycode),
						INDEX (country)
						)";

$sth = $dbh->prepare($sql);
$sth->execute;
$serror = $sth->errstr; if ($serror ne "") { die "SQL Syntax Error: $serror - From: $sql"; }  	 


##############################################################################################################################
#
# Load GeoLite2-Country-Locations-en.csv into hash 
# $H_country{$kname} and $H_country_code{$kcode}
# for referencing it when packing into world_ip_resolver table
#
##############################################################################################################################

print "Reading country data from GeoLite2-Country-Locations-en.csv...\n";

my $line;
my $linecount = 0;

my %H_country;
my %H_country_code;

# Read "GeoLite2-Country-Locations-en.csv" and load its data into two hashes:
# `%H_country` and `%H_country_code`. 
# The hashes map a concatenated key (e.g., "CN" + geoname_id) to country names and ISO
# codes, respectively. The code skips the first line of the CSV file (header row) by checking `$linecount != 0`.


open (WORLD_NAMES, "$data_directory/GeoLite2-Country-Locations-en.csv") || 	die "Could not open: $data_directory/GeoLite2-Country-Locations-en.csv\n";

	while (defined($line=<WORLD_NAMES>))
	{
	if ($linecount != 0)
	{
		my @line_items = split (/,/, $line);
		
			my $geoname_id 			= $line_items[0];
			my $continent_code		= $line_items[2];
			my $continent_name 		= $line_items[3];
			my $country_iso_code 	= $line_items[4];
			my $country_name 		= $line_items[5];
		
		my $kname = "CN" . $geoname_id;
		$H_country{$kname} = $country_name;
		
		my $kcode = "CO" . $geoname_id;
		$H_country_code{$kcode} = $country_iso_code;
		
	} #### End line count
	$linecount++;
	} ### End while loop

close (WORLD_NAMES);



##############################################################################################################################
#### Import GeoLite2-Country-Blocks-IPv4.csv
##############################################################################################################################

print "Importing data into world_ip_resolver_TMP table ...\n";

$linecount = 0;

### Initialize variables
my ($network, $geoname_id, $registered_country_geoname_id, $represented_country_geoname_id, $is_anonymous_proxy, $is_satellite_provider);
my ($iprange, $startip, $endip, $startnum, $endnum, $kname, $country, $kcode, $countrycode);
my $nr_indicate = 0;

open (FILE_WRITE, "> $data_directory/temp.tmp") || die "Could not open: $data_directory/temp.tmp for writing...\n";
open (FILETO_IMP, "$data_directory/GeoLite2-Country-Blocks-IPv4.csv") || die "Could not open: $data_directory/GeoLite2-Country-Blocks-IPv4.csv\n";
	while (defined($line=<FILETO_IMP>))
	{
	if ($linecount != 0)
	{
			($network, $geoname_id, $registered_country_geoname_id, $represented_country_geoname_id, $is_anonymous_proxy, $is_satellite_provider) 
				= split (/,/, $line);
			
			### Get $startip $endip
			$iprange = join("-", Net::CIDR::cidr2range($network));
			($startip, $endip) = split (/-/, $iprange);
			 
			### Get $startnum $endnum
			$startnum = &IP2LONG($startip);
			$endnum = &IP2LONG($endip);
			
			### Get $countrycode / $country
				$kname = "CN" . $geoname_id;
				$country = $H_country{$kname};
				$country =~ s/\"//g;
				
				$kcode = "CO" . $geoname_id;
				$countrycode = $H_country_code{$kcode};
			
			print FILE_WRITE qq["$startip","$endip","$startnum","$endnum","$countrycode","$country"\n];
			
			$nr_indicate++;
			if ($nr_indicate == 50000) 
				{
				$nr_indicate = 0; 
				print "Processed $linecount records for importing into DB...\n";
				}
			
	} #### End line count
	$linecount++;
	} ### End while loop
close (FILETO_IMP);
close (FILE_WRITE);




### Load data into tale world_ip_resolver_TMP
print "Loading data into database...\n";
$sql = qq[
	LOAD DATA INFILE '$data_directory/temp.tmp'
	INTO TABLE world_ip_resolver_TMP
	FIELDS TERMINATED BY ',' ENCLOSED BY '"'
	LINES TERMINATED BY '\n';
];
$sth = $dbh->prepare($sql);
$sth->execute;
$serror = $sth->errstr; if ($serror ne "") { die "SQL Syntax Error: $serror - From: $sql"; } 


### DROP old world_ip_resolver table and rename world_ip_resolver_TMP to world_ip_resolver    
$sql = "DROP TABLE IF EXISTS world_ip_resolver";
$sth = $dbh->prepare($sql);
$sth->execute;
$serror = $sth->errstr; if ($serror ne "") { die "SQL Syntax Error: $serror - From: $sql"; }  	 
#print "world_ip_resolver table dropped...\n";



#### Rename world_ip_resolver_TMP to world_ip_resolver
$sql = "RENAME TABLE world_ip_resolver_TMP TO world_ip_resolver\n";
$sth = $dbh->prepare($sql);
$sth->execute;
$serror = $sth->errstr; if ($serror ne "") { die "SQL Syntax Error: $serror - From: $sql"; }  	 
#print "world_ip_resolver_TMP renamed to world_ip_resolver ...\n";


$sth->finish;
$dbh->disconnect; 


### Remove temporary file that was loaded into table world_ip_resolver_TMP
unlink ("$data_directory/temp.tmp");


&log_new_data_loaded_event("New GeoLite2-Country-CSV data downloaded and imported into MySQL database");


print "Import Complete!\n";


}
#
#
#
#
#
#
#
###################################################################################################
# This Perl function `IP2LONG` converts an IP address in dotted decimal format (e.g. "192.168.1.1") 
# to a decimal (long) integer representation.
# It does this by splitting the IP address into its four octets, then calculating the decimal value 
# using the formula for converting IP addresses to integers. 
sub IP2LONG 
{
    my $address = $_[0];          
    my ($a, $b, $c, $d) = split /\./, $address;   
    my $decimal = $d + ($c * 256) + ($b * 256**2) + ($a * 256**3);
    return $decimal;
}









sub update_maxmind_country_csv
{

### Let's see if wget path exists
if (! -e $wget_path) { die "Cannot find wget executable: $wget_path. Check that the path to wget is correct in ip2country.conf"; }

### Let's get the last modified date of GeoLite2-Country-CSV.zip from Maxmind
#my $output = `$wget_path -S --method HEAD --user=$maxmind_account_id --password=$maxmind_license_key '$maxmind_permalink' 2>&1`;
my $output = "Last-Modified: Fri, 05 Sep 2025 18:31:37 GMT";

### Let's extract the last modified date from the header returned by Maxmind
my $last_modified_date = &extract_last_modified($output);
print "Maxmind's GeoLite2-Country-CSV last modified date: $last_modified_date\n";

### Let's see if our 'modified' date matches the modified date returned from Maxmind 
### If it doesn't match, we download the new file
my $filename = "$data_directory/last_update.dat";

### $file_content will hold the contents of $filename
my $file_content;

### Read $filename contents into $file_content
open(my $fh, '<', $filename) or die "Could not open file '$filename': $!";
	{
    local $/;   # undefines the input record separator
    $file_content = <$fh>;
	}
close($fh);

### If the last update dates don't match, we download the new file from maxmind because their file was newly updated
if ($last_modified_date ne $file_content)
	{
	print "Downloading the latest GeoLite2-Country-CSV.zip from Maxmind.\n";
	&download_maxmind_country_csv;

	### Update the last update date because we just downloaded a new file
	open(my $fh, '>', $filename) or die "Could not open file '$filename': $!";
		{
		print $fh $last_modified_date;
		}
	close($fh);

	### Unzip the downloaded file
	&unzip_geoip_csv;

	### Import the newly downloaded data into the database
	&doimport;

	### Cleanup by removing downloaded and unzipped files
	if ($delete_downloaded_files eq "Y")
		{
		unlink("$data_directory/GeoLite2-Country-CSV.zip");
		unlink("$data_directory/GeoLite2-Country-Blocks-IPv4.csv");
		unlink("$data_directory/GeoLite2-Country-Locations-en.csv");
		}

	}
	else
	{
	print "GeoLite2-Country-CSV data is up to date. Nothing to do. Exiting...\n";
	}



} ### end sub update_maxmind_country_csv
#
#
#
#
#
#
#This function extracts the Last-Modified date from an HTTP response header. It uses a
#regular expression to search for the "Last-Modified" header in the input `$http_text`, 
#and returns the date value if found, or `undef` if not found.
sub extract_last_modified {
    my ($http_text) = @_;

    # Look for the Last-Modified header (case-insensitive, robust against spacing)
    if ($http_text =~ /^\s*Last-Modified:\s*(.+)$/mi) {
        my $last_modified = $1;
        return $last_modified;
    }

    # Return undef if not found
    return undef;
}
#
#
#
#
#
#
#
# Download the MaxMind GeoLite2-Country-CSV file using `wget`. 
# Saves the file to a the data directory, authenticates with a MaxMind account ID and license key, and prints the output
# if debugging is enabled. If the download fails, it dies with an error message.
sub download_maxmind_country_csv
{
my $maxmind_output = 
`$wget_path -O $data_directory/GeoLite2-Country-CSV.zip --content-disposition --user=$maxmind_account_id --password=$maxmind_license_key '$maxmind_permalink' 2>&1`;

if ($debug eq "Y") 
{ 
print "\n\n\n===============================================================================================\n";
print $maxmind_output . ""; 
print "\n===============================================================================================\n\n\n";
}

if ($? != 0) { die "wget failed with exit code " . ($? >> 8) . "\nOutput:\n$maxmind_output\n"; }
}
#
#
#
#
#
#
sub unzip_geoip_csv
{

### Let's see if unzip path exists
if (! -e $unzip_path) 
	{ 
	die "Error: Cannot find unzip executable: $unzip_path. Check that the path to unzip is correct in ip2country.conf"; 
	}

### Let's check if zip file exists
if (! -e "$data_directory/GeoLite2-Country-CSV.zip") 
	{ 
	die "Error: Cannot find unzip $data_directory/GeoLite2-Country-CSV.zip. There was probably a problem downloading it... Exiting...\n"; 
	}

# Run unzip command -> GeoLite2-Country-Blocks-IPv4.csv
my $cmd = "$unzip_path -o -j '$data_directory/GeoLite2-Country-CSV.zip' '*/GeoLite2-Country-Blocks-IPv4.csv' -d '$data_directory' 2>&1";
my $output = `$cmd`;
my $exit_status = $? >> 8;
	# Check for errors
	if ($exit_status != 0) { print "Error unzipping file:\n$output\n"; exit; } else 
		{ print "Unzipped: 'GeoLite2-Country-Blocks-IPv4.csv' to '$data_directory'.\n"; }

# Run unzip command -> GeoLite2-Country-Blocks-IPv4.csv
my $cmd2 = "$unzip_path -o -j '$data_directory/GeoLite2-Country-CSV.zip' '*/GeoLite2-Country-Locations-en.csv' -d '$data_directory' 2>&1";
my $output2 = `$cmd2`;
my $exit_status2 = $? >> 8;
	# Check for errors
	if ($exit_status2 != 0) { print "Error unzipping file:\n$output\n"; exit; } else 
		{ print "Unzipped: 'GeoLite2-Country-Locations-en.csv' to '$data_directory'.\n"; }


}





sub display_help
{

print qq[import.pl is used to import the MaxMind GeoLite2-Country-CSV file into your MySQL database
so that ip2country.pl can be used to locally lookup IP addresses to countries.

Usage: perl import.pl -update

What import.pl does:
====================

The import.pl Perl script downloads the latest Maxmind GeoLite Country: CSV Format .zip file. 
The script then unzip's the GeoLite2-Country-CSV.zip to extract 
GeoLite2-Country-Blocks-IPv4.csv and GeoLite2-Country-Locations-en.csv

The script then reads the contents of GeoLite2-Country-Blocks-IPv4.csv and 
GeoLite2-Country-Locations-en.csv and imports the data contained in the CSV files into your MySQL 
database.

Once the IP / Country data is in the database, ip2country.pl can be used to locally lookup
IP addresses to countries.

For exammple: perl ip2country.pl 142.250.185.142

When Maxmind updates their GeoLite2-Country-CSV.zip file, (on their side) with new updated data,
the import.pl script will download the updated file and unzip it and re-import all data from 
the CSV files. When there is no new updated data from Maxmind, import.pl will see there is no 
new data and just exit gracefully.

It is recommended to run import.pl daily with a cron job to keep your local IP address data in your
mysql database up to date. Note that MaxMind's licensing policy states that the data they provide 
you with may not be used if it is older than 30 days. 

For more information on Maxmind GeoLite2-Country-CSV Format visit:
https://dev.maxmind.com/geoip/

];


}





sub log_new_data_loaded_event
{
my ($event) = @_;

   my $log = Log::Rolling->new(log_file => "$script_dir/ip2country.log",
                                 max_size => 1000,
                                 wait_attempts => 30,
                                 wait_interval => 1,
                                 mode => 0644
                                 );

     # Add a log entry line.
     $log->entry($event);
     
     # Commit all log entry lines in memory to file and roll the log lines
     # to accomodate max_size.
     $log->commit;

}








# Read configuration file (`ip2country.conf`) and parse its contents into a
# hash (`%config`). The file is expected to be in the same directory as the script, with a format of `key = value` per
# line, allowing for comments and whitespace.
sub get_configuration
{

my $full_path = abs_path($0);
my $script_dir = dirname($full_path);
my $conf_file = "$script_dir/ip2country.conf";


open(my $fh, '<', $conf_file) or die "Could not open file '$conf_file': $!";

while (my $line = <$fh>) 
	{
		chomp $line;
		$line =~ s/^\s+|\s+$//g;      # trim whitespace
		$line =~ s/\s+#.*$//;         # remove trailing comments
		next if $line =~ /^#/;        # skip full-line comments
		next if $line eq '';          # skip empty lines

		if ($line =~ /^(\w+)\s*=\s*(.*)$/) 
		{
		$config{$1} = $2;
		}
	}

close ($fh);

}
