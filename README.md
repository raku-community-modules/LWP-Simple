LWP::Simple for Raku
=================

![Test Windows and MacOS](https://github.com/raku-community-modules/LWP-Simple/workflows/Test%20Windows%20and%20MacOS/badge.svg)

This is a quick & dirty implementation of a LWP::Simple clone for Raku; it does both `GET` and `POST` requests.

Dependencies
============

LWP::Simple depends on the modules MIME::Base64 and URI,
which you can find at http://modules.raku.org/. The tests depends
on [JSON::Tiny](https://github.com/moritz/json).

Write:

    zef install --deps-only .

You'll have to
install [IO::Socket::SSL](https://github.com/sergot/io-socket-ssl) via

    zef install IO::Socket::SSL

if you want to work with `https` too.

Synopsis
========

```raku
use LWP::Simple;

my $content = LWP::Simple.get("https://raku.org");

my $response = LWP::Simple.post("https://somewhere.topo.st", { so => True }
```


Current status
==============

You can
use [HTTP::UserAgent](https://github.com/sergot/http-useragent)
instead, with more options. However, this module will do just fine in
most cases. 

Use
===

Use the installed commands:

     lwp-download.p6  http://eu.httpbin.org

Or

     lwp-download.p6  https://docs.perl6.org

If `ÌO::Socket::SSL` has been installed.

    lwp-get.p6  https://raku.org

will instead print to standard output.

Known bugs
==========

According
to
[issues raised](https://github.com/raku-community-modules/LWP-Simple/issues/40),
[in this repo](https://github.com/raku-community-modules/LWP-Simple/issues/28),
there could be some issues with older versions of MacOSx. This issue
does not affect the functionality of the module, but just the test
script itself, so you can safely install with `--force`. Right now,
it's working correctly (as far as tests go) with Windows, MacOSx and
Linux.

License
=======

This distribution is licensed under the terms of
the
[Artistic 2.0 license](https://www.perlfoundation.org/artistic-license-20.html#). You
can find a [copy](LICENSE) in the repository itself.
