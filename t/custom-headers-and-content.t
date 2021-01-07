use v6;
use Test;

use LWP::Simple;

plan 1;

if %*ENV<NO_NETWORK_TESTING> {
    diag "NO_NETWORK_TESTING was set";
    skip-rest("NO_NETWORK_TESTING was set");
    exit;
}

my $host    = 'http://eu.httpbin.org/anything';
my %headers = ( 'Content-Type' => 'application/json' );
constant message = "Hello from Raku";
my $content = '{"method":"echo","params":[' ~ message ~ '],"id":1}';
my $html    = LWP::Simple.post($host, %headers, $content);

if $html {
    ok(
        $html.match(message),
        'call to JSON-RPC service using headers and content params'
    );
}
else {
    skip("Unable to connect to test site '$host'", 1);
}

