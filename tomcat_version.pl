#!/usr/bin/perl
###
# This nagios check checks the version of tomcat you have set up on your server.  Checks by reading the directories provided by the -d switch by checking the default extracted name of the tomcat folder.  This script is useless if you rename your tomcat home once you've extracted it.

use warnings;
use strict;

my ($opt_a,$tc_home,$opt_b,$monitor_version) = @ARGV;

if (!$opt_a or $opt_a ne '-d' or !$tc_home or !$opt_b or $opt_b ne '-v' or !$monitor_version or $monitor_version !~ /6.0|7.0|8.0|8.5|9.0/){
    &usage();
}

$ENV{'PATH'} = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';

###
# These are all the prerequisites for the script to run, it will install anything missing at the time of execution.  Currently has only been tested on CentOS 6.8
###

my @req = qw(perl-libwww-perl perl-CPAN.x86_64 libgcc.x86_64 curl gcc);
my @perl = qw(LWP::Simple);

foreach my $p (@req){
    chomp(my $stat = `yum -q list installed $p &>/dev/null && echo '1' || echo '2'`);
    if($stat == 2){
        system("yum install $p -y &>/dev/null");
    }
}

chomp(my $cpan = `which cpanm &>/dev/null && echo '1' || echo '2'`);

if($cpan == 2){
    system('curl -s -L http://cpanmin.us | perl - --sudo App::cpanminus');
}

foreach my $x (@perl){
    eval "use $x";
    if($@){
        system("cpanm $x");
        eval "use $x";
    }
}

###

chomp(my $version = `ls -l $tc_home | grep \'^d\'| egrep \'apache-tomcat-$monitor_version\' | tail -n 1 | awk \'{print \$9}\'`);

if(!$version){
    print "This system does not appear to be running version - $monitor_version\n";
    exit 1;
}

my ($sysVersion) = $version =~ /apache-tomcat-(\d.+)/;

my ($subversion,$prefix) = $sysVersion =~ /^((\d+)\.\d+).+$/;

my $url = "http://tomcat.apache.org/download-${prefix}0.cgi";
my @html = split("\n",get($url));

my ($WebVersion) = &TomcatCurrentVersion($subversion,\@html);

if(!$WebVersion){
    print "UNKNOWN: Failed to get version from the web\n";
    exit 3;
}

if ($sysVersion eq $WebVersion){
    print "OK: No Updates Available\nCurrent Version - $sysVersion\n";
    exit 0;
}

my $secUrl = "http://tomcat.apache.org/security-${prefix}.html";
my @security = split("\n",get($secUrl));

my ($SecurityUpdateAvailable) = &CheckSecurity($WebVersion,\@security);

if($SecurityUpdateAvailable){
    print "CRITICAL: Security Update Available\nSystem Version - $sysVersion\nUpdate Version - $WebVersion\n";
    exit 2;
}
elsif(!$SecurityUpdateAvailable and $WebVersion ne $sysVersion){
    print "WARNING: Update Available\nSystem Version - $sysVersion\nUpdate Version - $WebVersion\n";
    exit 1;
}
else{
    print "UNKNOWN: Unknown Status\n";
    exit 3;
 }

sub TomcatCurrentVersion{
    my $sub = shift;
    my $update = shift;
    
    my ($ver);
    
    foreach my $line (@$update){
        if(($ver) = $line =~ /id="($sub\.\d.+)"/){
            last;
        }
    } 
    return $ver;
}

sub CheckSecurity{
    my $ver = shift;
    my $check = shift;
    
    my $stat = undef;
    
    foreach my $line (@$check){
        if(($stat) = $line =~ /Fixed_in_Apache_Tomcat.+($ver)/g){
            last;
        }
    }
    return $stat;
 }

 sub usage{
    print "Invalid Operation\n";
    print "Usage: $0 -d <tomcat home> -v <tomcat version> (versions need to be full version like 7.0, 8.5, 9.0 etc)\n";
    exit 3;
}