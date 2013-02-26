use strict;
  use Net::DNS::RR;
  use POE qw(Component::Server::DNS);

#  my $dns_server = POE::Component::Server::DNS->spawn( alias => 'dns_server', forward_only => 0 );
  my $dns_server = POE::Component::Server::DNS->spawn( alias => 'dns_server');

  POE::Session->create(
        package_states => [ 'main' => [ qw(_start handler log) ], ],
  );

  $poe_kernel->run();
  exit 0;

  sub _start {
    my ($kernel,$heap) = @_[KERNEL,HEAP];

    # Tell the component that we want log events to go to 'log'
    $kernel->post( 'dns_server', 'log_event', 'log' );

    # register a handler for any foobar.com suffixed domains
    $kernel->post( 'dns_server', 'add_handler',
        {
          event => 'handler',
          label => 'foobar',
          match => 'foobar\.com$',
        }
    );
    undef;
  }

  sub handler {
    my ($qname,$qclass,$qtype,$callback) = @_[ARG0..ARG3];
    my ($rcode, @ans, @auth, @add);

    if ($qtype eq "A") {
      my ($ttl, $rdata) = (3600, "10.1.2.3");
      push @ans, Net::DNS::RR->new("$qname $ttl $qclass $qtype $rdata");
      $rcode = "NOERROR";
    } else {
      $rcode = "NXDOMAIN";
    }


    $callback->($rcode, \@ans, \@auth, \@add, { aa => 1 });
    undef;
  }

  sub log {
    my ($ip_port,$net_dns_packet) = @_[ARG0..ARG1];
    $net_dns_packet->print();
    undef;
  }

