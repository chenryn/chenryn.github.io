#!D:\strawberryperl\perl\bin\perl.exe
use 5.014;
use strict;
use warnings;
use Data::Dumper;
use autodie;
use Net::DNS::Nameserver;

my $ns = new Net::DNS::Nameserver( LocalPort    => 5353,
                                   ReplyHandler => \&reply_handler,
                                   Verbose      => 1
                                 );

$ns->main_loop;

sub reply_handler {
    my ($qname, $qclass, $qtype, $peerhost, $query, $conn) = @_;
    my ($rcode, @ans, @auth, @add);

    $query->print;
#    print Dumper $conn;

    if ($qtype eq "A" && $qname =~ m/foobar.com$/ ) {
            my ($ttl, $rdata) = (3600, "10.1.2.3");
            my $rr = new Net::DNS::RR("$qname $ttl $qclass $qtype $rdata");
            push @ans, $rr;
            $rcode = "NOERROR";
    }elsif( $qtype eq "TXT" && $qname =~ m/(\w+)\.foobar\.com/i ) {
            my $ttl = 3600;
	    my $rdata = reverse($1) . $peerhost;
            my $rr = new Net::DNS::RR("$qname $ttl $qclass $qtype $rdata");
            push @ans, $rr;
            $rcode = "NOERROR";
    }else{
            $rcode = "NXDOMAIN";
    }

    # mark the answer as authoritive by setting the 'aa' flag
    return ($rcode, \@ans, \@auth, \@add, { aa => 1 });
}
