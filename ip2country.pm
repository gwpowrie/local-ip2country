package ip2country;

use strict;
use Exporter 'import';
use DBI;
use Net::CIDR;

# What functions we want to export by default
our @EXPORT_OK = qw(IP2Country);

# VERSION is required for CPAN modules
our $VERSION = '1.00 alpha';


# Simple function
sub resolve_ip 
{
my ($ip_address,				    ### Ip Address
    $IP_db_name,				    ### DB Name
    $IP_db_username,			  ### DB Username
    $IP_db_password,			  ### DB Password
    $IP_mysql_hostname,		  ### MySQL Hostname
    $IP_mysql_port			    ### MySQL Port
    ) = @_;

### Other variables used in function
my ($IP_dsn, $IP_dbh, $IP_sth, $IP_serror, $IP_country, @IP_row, $Ucountry);

### If the IP address is not valid, return "Invalid IP Address"
my $is_valid = &is_valid_ipv4($ip_address);
if ($is_valid < 1) { return "Invalid IP Address"; }

### If the IP is inside the private namespace
if ($ip_address =~ /192\.168\.0\./) { return "Private 192.168.0.*"; }

### Convert the IP address to a decimal
my $decip = &IP2LONG($ip_address);

# Connect to MySQL
if ($IP_mysql_hostname eq ""){$IP_dsn = "DBI:mysql:$IP_db_name";} else {$IP_dsn = "DBI:mysql:$IP_db_name:$IP_mysql_hostname:$IP_mysql_port";}
$IP_dbh = DBI->connect($IP_dsn, $IP_db_username, $IP_db_password);
if ( !defined $IP_dbh ) { die "Cannot connect to MySQL server: $DBI::errstr\n" . "Check that the databse name, database user name or database password is correct in config.cfg"; } 

	my $sql = "SELECT country FROM world_ip_resolver WHERE (startnum <= '$decip') AND (endnum >= '$decip')";
	$IP_sth = $IP_dbh->prepare($sql);
	$IP_sth->execute;
	$IP_serror = $IP_sth->errstr; if ($IP_serror ne "") {die "SQL Syntax Error: $IP_serror";} 
	
	while ( @IP_row = $IP_sth->fetchrow() )
		{
		$Ucountry = $IP_row[0];
		}

if ($Ucountry eq "") { $IP_country = "Unknown"; }


$IP_sth->finish;
$IP_dbh->disconnect; 


return $Ucountry;
}







sub is_valid_ipv4 {
    my ($ip) = @_;

    # Quick regex for 4 dot-separated numbers
    return 0 unless $ip =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/;

    # Check each octet is between 0–255
    for my $octet ($1, $2, $3, $4) {
        return 0 if $octet < 0 || $octet > 255;
    }
    return 1;
}






# Convert an IP address in dotted decimal format (e.g. "192.168.1.1") 
# to a decimal (long) integer representation.
sub IP2LONG {
	my $address = @_[0];
  my ($a, $b, $c, $d);
	($a, $b, $c, $d) = split '\.', $address;
	my $decimal = $d + ($c * 256) + ($b * 256**2) + ($a * 256**3);
	return $decimal;
}










1; 

__END__

=head1 NAME

IP2Country.pm - A simple module to resolve IP address to country using a MySQL database

=head1 SYNOPSIS

  use ip2country qw(resolve_ip);

=head1 DESCRIPTION

This Perl module is used to resolve an IP address to the country the IP belongs to.

=head1 AUTHOR

Walter Powrie

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut