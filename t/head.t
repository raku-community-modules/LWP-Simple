#!/usr/bin/env raku

use Test;
use LWP::Simple;


for <http  https> -> $prot {
    if $prot eq "https" {
        try require IO::Socket::SSL;
        if $! {
            skip-rest("IO::Socket::SSL not available");
            done-testing;
        }
    }
    subtest 'head' => {
        subtest "head fetched good content over $prot.uc()" => {
            with LWP::Simple.head($prot ~ '://eu.httpbin.org/html') {
                like $_<Content-Type>, rx/'text/html'/, 'Content is correct';
                like $_<Server>, rx/'gunicorn'/, 'Server is correct';
            }
        }

    }

}

done-testing;
