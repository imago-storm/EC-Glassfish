=head1 NAME

ECPDF::Client::REST

=head1 DESCRIPTION

This module provides a simple rest client for various interactions.
This rest client has compatible APIs with LWP::UserAgent and HTTP::Request.

=head1 SYNOPSIS

You can get ECPDF::Client::REST object using regular constructor: new(), or through context object.

During plugin development it is better to get it through context object.

%%%LANG=perl%%%
    sub stepGetContent {
        my ($pluginObject) = @_;

        # retrieving context object
        my $context = $pluginObject->newContext();
        # creating new ECPDF::Client::REST object
        my $rest = $context->newRESTClient();
        # creatung new HTTP::Request object using ECPDF APIs
        my $request = $rest->newRequest(GET => 'http://electric-cloud.com');
        # performing request and getting HTTP::Response object.
        my $response = $rest->doRequest($request);
        # printing response content
        print "Content: ", $response->decoded_content();
    }
%%%LANG%%%

=head1 METHODS

=over

=cut

package ECPDF::Client::REST;
use base qw/ECPDF::BaseClass/;
use ECPDF::ComponentManager;
use ECPDF::Log;
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
use Data::Dumper;
use Carp;
use URI::Escape qw/uri_escape/;

sub classDefinition {
    return {
        ua    => 'LWP::UserAgent',
        proxy => '*',
        oauth => '*'
    };
}

=item B<new>

Constructor. Creates new ECPDF::Client::REST object.

It has internal support of L<ECPDF::Component::Proxy>.

To use ECPDF::Client::REST with proxy you need to provide a proxy parameters to constructor. They are:

=over 4

=item B<url>

An address of the proxy to be used as http proxy.

=item B<username>

The username that is being used for proxy authorization.

=item B<password>

The password that is being used for username for proxy authorization.

=item B<debug>

Debug enabling switch. Debug output for ECPDF::Proxy will be enabled if this is passed as true.

%%%LANG=perl%%%
        my $rest = ECPDF::Client::REST->new({
            proxy => {
                url => 'http://squid:3128',
                username => 'user1',
                password => 'user2'
            }
        });
%%%LANG%%%

In that example ECPDF::Rest loads automatically L<ECPDF::Component::Proxy> and creates new ECPDF::Client::REST.

=back

=cut

sub new {
    my ($class, $params) = @_;

    logDebug("Creating ECPDF::Client::Rest with params: ", Dumper $params);
    if (!$params->{ua}) {
        $params->{ua} = LWP::UserAgent->new();
    }
    if ($params->{proxy}) {
        logDebug("Loading Proxy Component on demand.");
        my $proxy = ECPDF::ComponentManager->loadComponent('ECPDF::Component::Proxy', $params->{proxy});
        logDebug("Proxy component has been loaded.");
        $proxy->apply();
        $params->{ua} = $proxy->augment_lwp($params->{ua});
    }

    my $oauth = undef;
    if ($params->{oauth}) {
        # op stands for ouathParams
        my $op = $params->{oauth};

        if ($op->{oauth_version} ne '1.0') {
            croak "Currently OAuth version $op->{oauth_version} is not supported. Suported versions: 1.0";
        }

        for my $p (qw/request_method oauth_signature_method oauth_version request_token_path authorize_token_path access_token_path/) {
            if (!defined $op->{$p}) {
                croak "$p is mandatory for oauth component";
            }
        }
        logDebug("Loading ECPDF::Component::OAuth");
        $oauth = ECPDF::ComponentManager->loadComponent('ECPDF::Component::OAuth', $params->{oauth});
        logDebug("OAuth component has been loaded.");
    }
    my $self = $class->SUPER::new($params);

    if ($oauth) {
        $oauth->ua($self);
    }

    return $self;

}


=item B<newRequest>

Creates new HTTP::Request object.

This wrapper has been created to implement request augmenations using components during request object creation.

For example, if ECPDF::Client::Rest has been created with proxy support, it will return HTTP::Request object with applied proxy fields.

This method has the same API as HTTP::Request::new();

%%%LANG=perl%%%
    my $request = $rest->newRequest(GET => 'https://electric-cloud.com');
%%%LANG%%%

=cut

sub newRequest {
    my ($self, @params) = @_;

    my $req = HTTP::Request->new(@params);
    my $proxy = $self->getProxy();
    if ($proxy) {
        my $proxyComponent = ECPDF::ComponentManager->getComponent('ECPDF::Component::Proxy');
        $req = $proxyComponent->augment_request($req);
    }
    return $req;
}


=item B<doRequest>

Performs HTTP request, using HTTP::Request object as parameter.

Also, this method supports API of LWP::UserAgent::request() method.

This method returns HTTP::Response object.

%%%LANG=perl%%%
    my $request = $rest->newRequest(GET => 'https://electric-cloud.com');
    my $response = $rest->doRequest($request);
    print $response->decoded_content();
%%%LANG%%%

=cut

sub doRequest {
    my ($self, @params) = @_;

    my $ua = $self->getUa();
    return $ua->request(@params);
}


=item B<augmentUrlWithParams>

Helper method, that provides a mechanism for adding query parameters to URL, with proper escaping.

%%%LANG=perl%%%
    my $url = 'http://localhost:8080;

    $url = $rest->augmentUrlWithParams($url, {one=>'two'});
    # url = http://localhost:8080?one=two
%%%LANG%%%

=cut

sub augmentUrlWithParams {
    my ($self, $url, $params) = @_;

    if (!$url) {
        croak "URL expected";
    }
    if (!ref $params) {
        croak "Required HASH reference for params";
    }

    $url =~ s|\/*?$||gs;
    my $gs = '';
    for my $k (keys %$params) {
        $gs .= uri_escape($k) . '=' . uri_escape($params->{$k}) . '&';
    }
    $gs =~ s/&$//s;
    if ($url =~ m|\?|s) {
        $gs = '&' . $gs;
    }
    else {
        $gs = '?' . $gs;
    }
    $url .= $gs;
    return $url;
}


=back

=cut

1;
