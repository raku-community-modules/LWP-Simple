#!/usr/bin/env perl6

use v6.c;

BEGIN {
    try require IO::Socket::SSL;
    if ::('IO::Socket::SSL') ~~ Failure {
        print("1..0 # Skip: IO::Socket::SSL not available\n");
        exit 0;
    }
}

use Test;
use LWP::Simple;

lives-ok {
    LWP::Simple.get("http://github.com/");
}, "can retrieve http://github.com/";


done-testing;
# vim: expandtab shiftwidth=4 ft=perl6
