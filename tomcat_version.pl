#!/usr/bin/perl
###
# This nagios check checks the version of tomcat you have set up on your server.  Checks by reading the directories provided by the -d switch by checking the default extracted name of the tomcat folder.  This script is useless if you rename your tomcat home once you've extracted it.

use warnings;
use strict;

my $file_check = 1;
my $version;

my ($opt_a,$opt_b) = @ARGV;

if (not defined $opt_a){
    &usage(2);
}
elsif($opt_a eq '-v'){
    if(not defined $opt_b){
        print "Version Number Required With This Option\n";
        &usage(1);
    }
    $file_check = 0;
}
elsif($opt_a eq '-d' and not defined $opt_b){
    print "Tomcat Home Required With This Option\n";
    &usage(1);
}
elsif($opt_a !~ /-d|-v/){
    &usage(2);
}
   
$ENV{'PATH'} = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';

#####
#
# These are all the prerequisites for the script to run, it will install anything missing at the time of execution.  Currently has only been tested on CentOS 6.8
#
#####

my @req = qw(perl-libwww-perl perl-CPAN.x86_64 libgcc.x86_64 curl gcc);
my @perl = qw(LWP::Simple);

foreach my $p (@req){
    chomp(my $stat = `yum -q list installed $p &>/dev/null && echo '1' || echo '2'`);
    if($stat == 2){
        system("yum install $p -y &>/dev/null");
    }
}

if ($file_check == 1){
    my $file = "$opt_b/RELEASE-NOTES";
    
    if(! -e $file){
        print "RELEASE-NOTES do not appear to exist, please include full version you are monitoring using the -v switch\n";
        exit 3;
    }

    open(my $fh, "<$file") or die "Failed to open file!: $!\n";

    while (my $fline = <$fh>){
        if(($version) = $fline =~ /Apache Tomcat Version (\d.+)/g){
            last;
        }
    }
    
    close($fh);
}
else {
    $version = $opt_b;
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

my ($subversion,$prefix) = $version =~ /^((\d+)\.\d+).+$/;

my $url = "http://tomcat.apache.org/download-${prefix}0.cgi";
my @html = split("\n",get($url));

my ($WebVersion) = &TomcatCurrentVersion($subversion,\@html);

if(!$WebVersion){
    print "UNKNOWN: Failed to get version from the web\n";
    exit 3;
}

if ($version eq $WebVersion){
    print "OK: No Updates Available\nCurrent Version - $version\n";
    exit 0;
}

my $secUrl = "http://tomcat.apache.org/security-${prefix}.html";
my @security = split("\n",get($secUrl));

my ($SecurityUpdateAvailable) = &CheckSecurity($WebVersion,\@security);

if($SecurityUpdateAvailable){
    print "CRITICAL: Security Update Available\nSystem Version - $version\nUpdate Version - $WebVersion\n";
    exit 2;
}
elsif(!$SecurityUpdateAvailable and $WebVersion ne $version){
    print "WARNING: Update Available\nSystem Version - $version\nUpdate Version - $WebVersion\n";
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
        if(($ver) = $line =~ /id="($sub.+?)(\/|")/){
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
    my $mes = shift;
    
    if($mes == 1){
        print "Invalid Operation\n";
    }
    elsif($mes == 2){
        print "Switch Required To Operate (-d to define tomcat path or -v to define a particular version number\n";
    }
    print "Usage: $0 -d <tomcat home>| -v <version number (ie 8.0.36)>\n";
    exit 3;
}