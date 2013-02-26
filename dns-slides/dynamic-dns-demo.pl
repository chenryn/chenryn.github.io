#!D:\strawberryperl\perl\bin\perl.exe
use strict;
use warnings;
use autodie;
use 5.014;
use Net::IP::Match::Regexp qw/create_iprange_regexp match_ip/;
use Stanford::DNS;
use Stanford::DNSserver;

my $hostmaster = 'admin.renren-inc.com';
my $hostname   = '127.0.0.1';
my $soa        = rr_SOA($hostname, $hostmaster, time(), 3600, 1800, 86400, 0);
my $ns         = Stanford::DNSserver->new( listen_on => [ $hostname ],
	                                   debug     => 1,
					   logfunc   => sub { say },
					   daemon    => 'no',
					 );
my $host       = 'chenlin.rao.som.renren-inc.com';

my $regexp     = create_iprange_regexp({ '127.0.0.1/32' => 'localhost',
	                                 '10.0.0.0/8'   => 'ethernet',
				      });
my $iplist     = { $host => { ethernet => '10.10.10.10', localhost => '12.7.0.10'}, };

$ns->add_static( $host, T_SOA, $soa );
$ns->add_static( $host, T_NS, rr_NS($hostmaster) );

$ns->add_dynamic( $host => \&dyn_req );

$ns->answer_queries();

sub dyn_req {
    my ($domain,$residual,$qtype,$qclass,$dm,$from) = @_;
    my $ttl = 3600;
    if ( $qtype == T_A ) {
        my $ip = dyn_match($domain, $from);
        $dm->{'answer'} .= dns_answer(QPTR, T_A, C_IN, $ttl, rr_A($ip));
        $dm->{'ancount'} += 1;
        return 1;
    };
    if ( $qtype == T_TXT ) {
	if ( $domain =~ m/^(\w+\.\w+)\.som\.(renren-inc\.com)/ ) {
	    $dm->{'answer'} .= dns_answer(QPTR, T_TXT, C_IN, $ttl, rr_TXT("Email address: $1\@$2"));
            $dm->{'ancount'} += 1;
        };
    };
    if ( ! $dm->{ancount} ) {
        $dm->{rcode} = NXDOMAIN;
    };
};

sub dyn_match {
    my ( $domain, $from ) = @_;
    my $area = match_ip($from, $regexp);
    return ($1<<24)|($2<<16)|($3<<8)|$4 if $iplist->{"$host"}->{"$area"} =~ m/(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/;
};
