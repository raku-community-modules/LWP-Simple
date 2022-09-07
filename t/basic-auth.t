#
# Test the basic auth code path
#
 
use v6;
use Test;

use LWP::Simple;

plan 9;

if %*ENV<NO_NETWORK_TESTING> {
    diag "NO_NETWORK_TESTING was set";
    skip-rest("NO_NETWORK_TESTING was set");
    exit;
}

my $basic-auth-url = 'https://ron:Camelia@www.software-path.com/p6-lwp-simple/basic-auth/';
my @url = LWP::Simple.parse_url($basic-auth-url);

is(@url[0], 'https', 'Scheme parsed correctly');
is(@url[1], 'ron:Camelia@www.software-path.com', 'Hostname contains basic auth info');
is(@url[2], 443, 'HTTPS demands port 443');
is(@url[3], '/p6-lwp-simple/basic-auth/', 'Path extracted correctly');

is(@url[4]<user>, 'ron', 'Basic auth info extracted correctly: user');
is(@url[4]<password>, 'Camelia',  'Basic auth info extracted correctly: pass');
is(@url[4]<host>, 'www.software-path.com',  'Basic auth info extracted correctly: hostname');

# Encode test
is(
    LWP::Simple.base64encode('someuser', 'somepass'),
    'c29tZXVzZXI6c29tZXBhc3M=',
    'Base64 encoding works'
);

$basic-auth-url ~~ s/^https/http/;
skip "#51 'www.software-path.com' not resolving";
#my $html = LWP::Simple.get($basic-auth-url);
# ok($html.match('protected'), 'Got protected url');

