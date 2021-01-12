use v6;
use Test;

use LWP::Simple;

plan 10;

if %*ENV<NO_NETWORK_TESTING> {
    diag "NO_NETWORK_TESTING was set";
    skip-rest("NO_NETWORK_TESTING was set");
    exit;
}

# test getstore under http
getstore-tests('http://www.google.com', rx:i/google/);

try require IO::Socket::SSL;
if $! {
    skip-rest("IO::Socket::SSL not available");
    exit 0;
}

# test getstore under https
getstore-tests('https://openssl.org', rx:i/ssl/);

sub getstore-tests($url, $rx) {
    my $fname = $*SPEC.catdir($*TMPDIR, "./tmp-getstore-$*PID");
    try unlink $fname;

    ok(
        LWP::Simple.getstore($url, $fname),
        'getstore() returned success'
       );

    my $fh = open($fname);
    ok($fh, 'Opened file handle written by getstore()');

    ok($fh.slurp ~~ $rx, 'Found pattern in downloaded file');

    ok($fh.close, 'Close the temporary file');

    ok(unlink($fname), 'Delete the temporary file');
}
