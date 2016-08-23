#!/usr/bin/perl

use warnings;
use strict;

######
# These are all the prerequisites for the script to run, it will install anything missing at the time of execution
######

my @req = qw(perl-libwww-perl perl-CPAN.x86_64 libgcc.x86_64 curl gcc);
my @perl = qw(LWP::Simple);

foreach my $p (@req){
    chomp(my $stat = `yum -q list installed $p &>/dev/null && echo '1' || echo '2'`);
    if($stat == 2){
        system("yum install $p -y &>/dev/null");
    }
}

chomp(my $cpan = `which cpanm &>/dev/null && echo '1' || echo '2'`);

if($cpan == 2){ system('curl -s -L http://cpanmin.us | perl - --sudo App::cpanminus'); }

foreach my $x (@perl){
    eval "use $x";
    if($@){
        system("cpanm $x");
        eval "use $x";
    }
}

######

$ENV{DAEMON_HOME} = "/usr/local/lib/commons-daemon*/";
chomp(my $loc_ver =`ls -l \$DAEMON_HOME| grep \'^d\' | grep \"commons-daemon\" | tail -n 1 | awk \'{print \$9}\'`);
$loc_ver =~ s/commons-daemon-(\d.+)\-.+/Commons Daemon $1/g;

my $cd_url = 'http://commons.apache.org/proper/commons-daemon/download_daemon.cgi';

my $content = get($cd_url);
my ($web_ver) = $content =~ /<div class="section"><h2>(Commons Daemon.+?)\s\</g;

if ($loc_ver eq $web_ver){
    print "OK: Versions Match\nLocal - $loc_ver\nWeb - $web_ver\n";
    exit 0;
}
elsif ($loc_ver ne $web_ver){
    print "WARNING: Update Available\nLocal - $loc_ver\nWeb - $web_ver\n";
    exit 1;
}
else {
    print "UNKNOWN: Unknown Status\n";
    exit 3;
}