#!/usr/bin/env perl6

use v6.c;

use Test;
use LWP::Simple;

lives-ok {
    LWP::Simple.get("http://github.com/");
}, "can retrieve http://github.com/";


done-testing;
# vim: expandtab shiftwidth=4 ft=perl6
