use v6;
use Test;
use LWP::Simple;

constant TEST_SERVER = 'http://no-ssl-http-module-tester.perl6.org';

plan :skip-all<NO_NETWORK_TESTING env var is set> if %*ENV<NO_NETWORK_TESTING>;
plan 1;

is LWP::Simple.get(TEST_SERVER ~ '/get-no-content-length.pl'),
    "Hello meows\nTest passed\n",
    'we pulled whole document without sizing from server';
