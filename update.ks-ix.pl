#!/usr/bin/perl

use v5.10;
use strict;
use warnings;
use Getopt::Std;

# aptitude install libnet-openssh-perl
use Net::OpenSSH;

# aptitude install libnet-telnet-perl
use Net::Telnet;

# aptitude install libtext-diff-perl
use Text::Diff;

my %opts;
getopts('u:p:r:', \%opts);
unless (defined $opts{r} ) {
    say "-rrouter";
    exit 254;
}
unless (defined $opts{u} ) {
    say "-uusername";
    exit 254;
}
unless (defined $opts{p} ) {
    say "-ppassword";
    exit 255;
}

my ($rf_rt, $rf_jn) = ( join("\n",sort(split("\n",getRTConfig("AS-KS-IX")))), join("\n",sort(split"\n",getJunOSConfig("AS-KS-IX", $opts{r}, $opts{u}, $opts{p}))) );
my $diff = diff \$rf_jn, \$rf_rt;
setJunOSConfig($diff, "AS-KS-IX", $opts{r}, $opts{u}, $opts{p}) if length($diff)>0;
exit 0;

sub getRTConfig {
    my $as = shift if @_;
    return "" unless $as;
    my $ret;
    open (RT, "echo \"\@rtconfig access_list filter ".$as."\" | rtconfig -protocol ripe -config junos |") || die "Failed run rtconfig: $!\n";
    while (<RT>) {
        s/^\s*//;
        next unless /^route-filter\s+/;
        $ret .= $_;
    }
    close RT;
    return $ret;
}

sub getJunOSConfig {
    my $ps = shift if @_;
    my $router = shift if @_;
    my $user = shift if @_;
    my $pass = shift if @_;
    return "" unless $ps;

    my $ssh = Net::OpenSSH->new( $router, user => $user, password => $pass, master_opts => [-o => "StrictHostKeyChecking=no"] );
    $ssh->error && die "Couldn't establish SSH connection: ". $ssh->error;

    my $ret = join("", jCmd($ssh, sprintf("show configuration policy-options policy-statement %s term prefixes from | match ^route-filter | no-more", $ps)) );

    undef $ssh;

    return $ret;
}
sub setJunOSConfig {
    my $diff = shift;
    my $ps = shift if @_;
    my $router = shift if @_;
    my $user = shift if @_;
    my $pass = shift if @_;
    return "" unless $ps;

    my $ret = "";
    foreach my $line ( split("\n", $diff) ) {
        next unless $line =~ /^[+-]/;
        $line =~ s/;$//;
        if ($line =~ /^-/) {
            $line =~ s/\s+\w+$//;
            $line =~ s/^-//;
            $line = sprintf("delete policy-options policy-statement %s term prefixes from %s\n", $ps, $line);
            $ret .= $line;
        } else {
            $line =~ s/^\+//;
            $line = sprintf("set policy-options policy-statement %s term prefixes from %s\n", $ps, $line);
            $ret .= $line;
        }
    }
    doCmd( $router, $user, $pass, $ret );
    return $ret;
}

sub jCmd {
    my $ssh = shift if @_;
    my $cmd = shift if @_;
    my @list = $ssh->capture($cmd);
    $ssh->error && die "remote '$cmd' command failed: " . $ssh->error;
    return @list;
}

sub doCmd {
    my $router = shift if @_;
    my $user = shift if @_;
    my $pass = shift if @_;
    my $cmdin = shift if @_;

    sub diessh {
        map { print; } @_ if @_;
        die;
    }

#   open STDERR, '>', "/dev/null";
    my $ssh = Net::OpenSSH->new( $router, user => $user, password => $pass, master_opts => [-o => "StrictHostKeyChecking=no"] );
    $ssh->error && die "Couldn't establish SSH connection: ". $ssh->error;
    my ($pty, $pid) = $ssh->open2pty();
    my $session = Net::Telnet->new( -fhopen => $pty, -prompt => '/.*[>#]\s+$/', -timeout=>60 );
    $session->waitfor(-match => $session->prompt, -errmode => "return") || diessh "wait failed: " . $session->lastline;
    $session->cmd(String=>'configure private');
    my $cmdc = 0;
    foreach my $cmd ( split "\n", $cmdin ) {
        $session->waitfor(-match => $session->prompt, -errmode => "return") || diessh "wait failed: " . $session->lastline;
        $session->cmd(String=>$cmd);
        say ".> ".$cmd;
        $cmdc++;
    }
    $session->waitfor(-match => $session->prompt, -errmode => "return") || diessh "wait failed: " . $session->lastline;
    $session->cmd(String=>'commit and-quit', Timeout=>10*$cmdc);
    $session->waitfor(-match => $session->prompt, -errmode => "return") || diessh "wait failed: " . $session->lastline;
    $session->close;
    waitpid($pid, 0);
    undef $session;
    undef $ssh;
#   open STDERR, '>', "/dev/stderr";
}

