# Local IP2Country

Local IP2Country is a set of Perl scripts that lets you convert IP Addresses to Countries from your own locally hosted MySQL database. The idea behind 'Local IP2Country' is to let you locally obtain the countries from IP Addresses instead of using a remote API somewhere that is likely not free or comes with limits, if it is free.

'Local IP2Country' has a Perl import script to automatically download and import [MaxMind.com's](http://www.maxmind.com) GeoLite2-Country-CSV data into your own locally hosted MySQL database. Once the data has been imported locally into MySQL, you simply pass on the IP address to ip2country.pl and it returns the country the IP belongs to.

## Requirements:

**Linux: Ubuntu/Debian or some other flavour of Linux** <br>
Local Ip2Country has only been tested on Linux. Windows support not available at present but it is likely that it will work on Windows.

**Perl**<br>
Your linux machine or server will need to have [Perl](https://www.perl.org) installed.

**MySQL or MariaDB**<br>
You will need an installed and functioning MySQL or MariaDB database server. The database user will also need the FILE privilege to import data into the database.

**Internet Connection:**<br>
You will need to have an Internet connection so that the database can be updated with new data from [MaxMind.com](http://www.maxmind.com). You will also need to configure a CRON Job so that 'Local IP2Country' can keep your database updated because MaxMind's licensing policy states that the data they provide you with may not be used if it is older than 30 days. 

**Account at MaxMind.com**<br>
You will need a  [MaxMind.com](http://www.maxmind.com) account. (Creating an account with them is free.) Once you have an account you will need to configure 'Local IP2Country' with your MaxMind Account ID and MaxMind License Key. See the installation instructions below for more detailed information on doing this. Note that I'm in no way affiliated with MaxMind.com.

**Perl Modules**<br>
You will need to install the following Perl mdoules. You will normally install them with the [cpan](https://www.cpan.org/) program. The cpan program, which is the command-line interface for the CPAN.pm module, is a standard part of the Perl distribution. You can find out how to install Perl modules [here.](https://www.cpan.org/modules/INSTALL.html)
<br>
**Perl Modules Needed:**
<ul>
    <li>DBI - Used for connections to MySQL</li>
    <li>Net::CIDR</li>
    <li>Log::Rolling</li>
</ul>


## Installation Instructions:

**1. Extract the .zip install file to your computer/server**<br>
Extract the contents to **/usr/local/ip2country** for example.

**2. Create a MySQL/MariaDB Database.** You could call it **ip2country** for example. It is usually easiest to use something like [MyPHPAdmin](https://www.phpmyadmin.net/) for this, if you don't want to do it manually.

**3. Configure 'Local IP2Country'**<br>
Open ip2country.conf with something like [MS Visual Code.](https://code.visualstudio.com/) <br>
<ul>
    <li>db_name = Supply your MySQL Database Name you created.</li>
    <li>db_username = Supply a MySQL Database User Name.</li>
    <li>db_password = Supply a MySQL Database User Password.</li>
    <li>mysql_hostname = This is normally 'localhost', so leave it as the default value unless you run MySQL on a remote host.</li>
    <li>mysql_port = This is normally '3306', so leave it as the default value unless you run MySQL on another port.</li>
    <li>maxmind_account_id = Your maxmind account ID. You can get it by logging into MaxMind.com</li>
    <li>maxmind_permalink = Leave this 'as is' unless the permalink at MaxMind changed.</li> 
    <li>wget_path = This is the path to 'wget' that needs to be installed on your system. Many flavours of Linux normally has it pre-installed. To get the path type: 'which wget' in the command line</li>
    <li>unzip_path = This is the path to the 'unzip' program that is used to unzip .zip files. Some flavours of Linux has it pre-installed. To get the path, type: 'which unzip' in the command line</li>    
</ul>

## Using Local IP2Country:

Once configured, you need to import the GeoLite2-Country-CSV data from MaxMind.com into your MySQL or MariaDB database. This can be done by running import.pl as follows: 

**perl import.pl -update**

When you run the above command, the GeoLite2-Country-CSV data will be imported into your MySQL or MariaDB database.

Running **perl import.pl -update** again will most likely not result in the data being imported because import.pl will only download the new  GeoLite2-Country-CSV data from MaxMind.com if MaxMind.com released an update to their IP/Country data.

It is recommended that you run **perl import.pl -update** as a Cron JOB on a daily basis because MaxMind's licensing policy states that the data they provide may not be used if it is older than 30 days.

Now that the GeoLite2-Country-CSV data is inside your MySQL or MariaDB database, you can get the country an IP belongs to, by running as an example: 

**perl ip2country.pl 142.251.47.142**

## Other Notes

Each time **import.pl** downloads a new MaxMind GeoLite2-Country-CSV file and updates the database, a log entry will be written inside ip2country.log so that you may know when a new data set was loaded.

