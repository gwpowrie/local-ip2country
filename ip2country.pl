#!/usr/bin/perl

############################################################################################################
#
# Local IP2Country - Resolve an IP address to the country the IP belongs to
#
############################################################################################################

use strict;
use FindBin '$RealBin';
use lib $RealBin;
use Cwd 'abs_path';
use File::Basename;
use ip2country;

my %config;
&get_configuration;

### Let's put configuration into easier to use variables
my $db_name = $config{db_name};
my $db_username = $config{db_username};
my $db_password = $config{db_password};
my $mysql_hostname = $config{mysql_hostname};
my $mysql_port = $config{mysql_port};



## Check if an IP address was provided as a command-line argument 
if (!defined $ARGV[0]) ### If the IP address is not defined display help
	{ 
	&display_help; 
	}
	else
	{
 	### use the ip2country::resolve_ip function to resolve the IP address to a country and prints the result
	my $country = ip2country::resolve_ip($ARGV[0],				### Ip Address
										 $db_name,				### DB Name
										 $db_username,			### DB Username
										 $db_password,			### DB Password
										 $mysql_hostname,		### MySQL Hostname
										 $mysql_port			### MySQL Port
										 );
	print $country . "\n";
	}








sub display_help
{

print qq[To use Local IP2Country, please run the following command:
perl ip2country.pl <ip_address>
The IP address will return the country the IP belongs to.
];

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
