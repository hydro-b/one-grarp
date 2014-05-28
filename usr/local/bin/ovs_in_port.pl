#!/usr/bin/perl -w
BEGIN { $ENV{PATH} = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games'; }
use strict;
use Data::Dumper;

my $switch_name = $ARGV[0];
my $mac_address = $ARGV[1];
if ((not defined $switch_name or not defined $mac_address) or
    ($switch_name eq "" or $mac_address eq "")) {
    die "Usage: $0 switch_name ma:ca:dd:re:ss:00"
}

my $data = {};

open(IN, "/usr/bin/sudo /usr/bin/ovs-ofctl dump-flows $switch_name |") or die "Can't fork ovs-ofctl: $! ($?)\n";
while (my $line = <IN>) {
    next if $line !~ m#\s+cookie=#;
    $line =~ s#\sactions=#, actions=#;

    my @elems = split /,/, $line;
    my $tmp_hash = {};   
    foreach my $elem (@elems) {
        if ($elem =~ /=/) {
            my ($key, $value) = $elem =~ m#\s*([^=]+)=(.*)\s*#;
            $$tmp_hash{$key} = $value;
        } else {
            $$tmp_hash{$elem} = '1';
        }
    }

    $$tmp_hash{dl_src} ||= "UNDEF";
    $$data{$$tmp_hash{dl_src}} = $tmp_hash;
}
close(IN);

if (defined $$data{$mac_address}) {
    print $$data{$mac_address}{in_port} . "\n";
} else {
    print "Not found: '$mac_address'\n";
}
