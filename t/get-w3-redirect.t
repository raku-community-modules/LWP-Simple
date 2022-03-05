use v6;
use Test;

use LWP::Simple;

plan 1;

if %*ENV<NO_NETWORK_TESTING> {
    diag "NO_NETWORK_TESTING was set";
    skip-rest("NO_NETWORK_TESTING was set");
    exit;
}

try require IO::Socket::SSL;
if $! {
    skip-rest("IO::Socket::SSL not available");
    exit 0;
}

my $html = LWP::Simple.get('http://jigsaw.w3.org/HTTP/300/301.html',
        :User-Agent("CameliaTestBrowser"));

ok(
    $html.match('Redirect test page'),
    'Was redirected to w3 redirect test page'
);
