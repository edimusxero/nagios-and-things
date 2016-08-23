#!/usr/bin/perl

use warnings;
use strict;

###
# These are all the prerequisites for the script to run, it will install anything missing at the time of execution
###

my @req = qw(perl-libwww-perl perl-CPAN.x86_64 libgcc.x86_64 curl);
my @perl = qw(LWP::Simple HTML::Strip);

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

$ENV{JAVA_HOME} = "/usr/local/lib/jdk*/java";
chomp(my $version = `\$JAVA_HOME/bin/java -version 2>&1 | head -n 1 | awk -F \'\"\' \'{print \$2}\'`); 

my $url = 'http://www.oracle.com/technetwork/java/javase/downloads/index.html';
my @html = split("\n",get($url));

$version =~ s/^\d+\.(\d+)\..+\_(\d+)$/$1u$2/g;
$version = "Java SE $version";

my($currentVersion,$updateDescription) = &parseHTML(@html);

if ($version eq $currentVersion){
    print "OK: Versions match\nServer Version $version\nOracle Version $currentVersion\n";
    exit 0;
}
elsif ($version ne $currentVersion){
    if($updateDescription =~ /security fixes/g){
        print "CRITICAL: Update with security update available -- $updateDescription\nServer Version $version\nOracle Version $currentVersion\n";
        exit 2;
    }
    else{
        print "WARNING: Update Available\nServer Version $version\nOracle Version $currentVersion\n";
        exit 1;
    }
}
else {
    print "UNKNOWN: Unknown Error\n";
    exit 3;
}

sub parseHTML{
    my @content = @_;
    my $hs = HTML::Strip->new();
    my ($java,$description);
    my $cnt = 1;
    foreach my $line (@content){
        if($line =~ /id="javasejdk"/){
            my $text = $hs->parse($line);
            ($java) = $text =~ /([A-Za-z\s\d]+)/;
            $java =~ s/^\s+|\s+$//g;
            $description = $hs->parse($content[$cnt]);
            $description =~ s/^\s+|\s+$//g;
            $hs->eof;
            last;
        }
        $cnt++;
    }
    return ($java,$description);
}
