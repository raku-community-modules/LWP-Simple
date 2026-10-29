#!/usr/bin/env raku

use Test;
use LWP::Simple;


for <http  https> -> $prot {
    if $prot eq "https" {
        try require IO::Socket::SSL;
        if $! {
            diag("IO::Socket::SSL not available, not testing $prot");
            next;
        }
    }
    subtest "head fetched good content over $prot.uc()" => {
        with LWP::Simple.head($prot ~ '://eu.httpbin.org/html') {
            .&isa-ok: Hash, "header parsed";
            .keys.&ok, "header has fields";
        }
    }

}

done-testing;
