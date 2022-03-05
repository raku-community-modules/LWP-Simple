# ----------------------
# LWP::Simple for Perl 6
# ----------------------
use v6;
use MIME::Base64;
use URI;
use URI::Escape;

unit class LWP::Simple:auth<perl6>:ver<0.107>;
constant $VERSION = ::?CLASS.^ver;


class X::LWP::Simple::Response is Exception {

    has Str $.status is rw;
    has Hash $.headers is rw;
    has Str $.content is rw;

    method Str() {
        return ~self.status;
    }

    method gist() {
        return self.Str;
    }
}

enum RequestType <GET POST PUT HEAD DELETE>;

has Str $.default_encoding = 'utf-8';
our $.force_encoding;
our $.force_no_encode;
our $.class_default_encoding = 'utf-8';

# these were intended to be constant but that hit pre-compilation issue
my Buf $crlf = Buf.new(13, 10);
my Buf $http_header_end_marker = Buf.new(13, 10, 13, 10);
my Int constant $default_stream_read_len = 2 * 1024;

method base64encode ($user, $pass) {
    my MIME::Base64 $mime .= new();
    my $encoded = $mime.encode_base64($user ~ ':' ~ $pass);
    return $encoded;
}

method get (Str $url, %headers = {}, Bool :$exception ) {
    self.request_shell(RequestType::GET, $url, %headers, :$exception )
}

method delete (Str $url, %headers = {}, Bool :$exception) {
    self.request_shell(RequestType::DELETE, $url, %headers, :$exception )
}

method post (Str $url, %headers = {}, Any $content?, Bool :$exception ) {
    self.request_shell(RequestType::POST, $url, %headers, $content, :$exception )
}

method put (Str $url, %headers = {}, Any $content?, Bool :$exception ) {
    self.request_shell(RequestType::PUT, $url, %headers, $content, :$exception )
}

method head (Str $url, %headers = {}, Bool :$exception ) {
    self.request_shell(RequestType::HEAD, $url, %headers, :$exception )
}

method request_shell (RequestType $rt, Str $url, %headers = {}, Any $content?, Bool :$exception ) {

    return unless $url;
    die "400 URL must be absolute <URL:$url>\n"
        unless $url.starts-with('https://') or $url.starts-with('http://');

    # The `require` must not be inside a block; because we need its symbols
    # later in the code and it exports them lexically.
    my $ssl = $url.starts-with('https://') and (
        (try require IO::Socket::SSL) !=== Nil
        or die "501 Protocol scheme 'https' is only supported if "
            ~ "IO::Socket::SSL is installed <URL:$url>\n"
    );

    my ($scheme, $hostname, $port, $path, $auth) = self.parse_url($url);

    %headers{'Connection'} = 'close';
    %headers{'User-Agent'} //= "LWP::Simple/$VERSION Raku/$*PERL.compiler.name()";

    if $auth {
        $hostname = $auth<host>;
        my $user = $auth<user>;
        my $pass = $auth<password>;
        my $base64enc = self.base64encode($user, $pass);
        %headers<Authorization> = "Basic $base64enc";
    }

    %headers<Host> = $hostname;

    if ($rt ~~ any(RequestType::POST, RequestType::PUT) && $content.defined) {
        # Attach Content-Length header
        # as recommended in RFC2616 section 14.3.
        # Note: Empty content is also a content,
        # header value equals to zero is valid.
        %headers{'Content-Length'} = $content.encode.bytes;
    }

    my ($status, $resp_headers, $resp_content) =
        self.make_request($rt, $hostname, $port, $path, %headers, $content, :$ssl);

    given $status {

        when / <[4..5]> <[0..9]> <[0..9]> / {
            if $exception {
                X::LWP::Simple::Response.new(
                    status => $status,
                    headers => $resp_headers,
                    content => self!decode-response( :$resp_headers, :$resp_content )
                ).throw;
            }
            else {
                return Nil;
            }
        }

        when / 30 <[12]> / {
            my $new_url = $resp_headers.pairs.first( *.key.lc eq 'location' ).value;
            if ! $new_url {
                die "Redirect $status without a new URL?";
            }

            # Watch out for too many redirects.
            # Need to find a way to store a class member
            #if $redirects++ > 10 {
            #    say "Too many redirects!";
            #    return;
            #}

            return self.request_shell($rt, $new_url, %headers, $content);
        }

        when / 20 <[0..9]> / {
            if ( $rt == RequestType::HEAD ) {
                return $resp_headers;
            } else {
                return self!decode-response( :$resp_headers, :$resp_content );
            }
        }

        # Response failed
        default {
            return;
        }
    }

}

method !decode-response( :$resp_headers, :$resp_content ) {
    my %resp_header_lowercase = $resp_headers.kv.map( -> $k, $v { $k.lc => $v });
    # should be fancier about charset decoding application - someday
    if ($.force_encoding) {
        return $resp_content.decode($.force_encoding);
    }
    elsif (not $.force_no_encode) && self!is-text(:%resp_header_lowercase) {
        my $charset = (%resp_header_lowercase<content-type> ~~ /charset\=(<-[;]>*)/)[0];
        $charset = $charset ?? $charset.Str !!  self ?? $.default_encoding !! $.class_default_encoding;
        return $resp_content.decode($charset);
    }
    else {
        return $resp_content;
    }
}

method !is-text(:%resp_header_lowercase --> Bool) {
    so ( %resp_header_lowercase<content-type> &&
      %resp_header_lowercase<content-type> ~~ /   $<media-type>=[<-[/;]>+] [ <[/]> $<media-subtype>=[<-[;]>+] ]? /  &&
      (   $<media-type> eq 'text' || (   $<media-type> eq 'application' && $<media-subtype> ~~ /[ ecma | java ]script | json/)) );
}

method parse_chunks(Blob $b is rw, $sock) {
    my Int ($line_end_pos, $chunk_len, $chunk_start) = (0) xx 3;
    my Blob $content = Blob.new();

    # smallest valid chunked line is 0CRLFCRLF (ascii or other 8bit like EBCDIC)
    while ($line_end_pos + 5 <= $b.bytes) {
        while ( $line_end_pos +4 <= $b.bytes  &&
                $b.subbuf($line_end_pos, 2) ne $crlf
        ) {
            $line_end_pos++
        }
#       say "got here x0x pos ", $line_end_pos, ' bytes ', $b.bytes, ' start ', $chunk_start, ' some data ', $b.subbuf($chunk_start, $line_end_pos +2 - $chunk_start).decode('ascii');
        if  $line_end_pos +4 <= $b.bytes &&
            $b.subbuf(
                $chunk_start, $line_end_pos + 2 - $chunk_start
            ).decode('ascii') ~~ /^(<.xdigit>+)[";"|\r?\n]/
        {

            # deal with case of chunk_len is 0

            $chunk_len = :16($/[0].Str);
#            say 'got chunk len ', $/[0].Str;

            # test if at end of buf??
            if $chunk_len == 0 {
                # this is a "normal" exit from the routine
                return True, $content;
            }

            # think 1CRLFxCRLF
            if $line_end_pos + $chunk_len + 4 <= $b.bytes {
#                say 'inner chunk';
                $content ~= $b.subbuf($line_end_pos +2, $chunk_len);
                $line_end_pos = $chunk_start = $line_end_pos + $chunk_len +4;

                if $line_end_pos + 5 > $b.bytes {
                    # we don't even have enough at the end of our buffer to
                    # have a minimum valid chunk header. Assume this is
                    # unfortunate coincidence and read at least enough data for
                    # a minimal chunk header
                    $b ~= $sock.read(5);
                }
            }
            else {
#                say 'last chunk';
                # remaining chunk part len is chunk_len with CRLF
                # minus the length of the chunk piece at end of buffer
                my $last_chunk_end_len =
                    $chunk_len +2 - ($b.bytes - $line_end_pos -2);
                $content ~= $b.subbuf($line_end_pos +2);
                if $last_chunk_end_len > 2  {
                    $content ~= $sock.read($last_chunk_end_len -2);
                }
                # clean up CRLF after chunk
                $sock.read(min($last_chunk_end_len, 2));

                # this is a` "normal" exit from the routine
                return False, $content;
            }
        }
        else {
#            say 'extend bytes ', $b.bytes, ' start ', $chunk_start, ' data ', $b.subbuf($chunk_start).decode('ascii');
            # maybe odd case of buffer has just part of header at end
            $b ~= $sock.read(20);
        }
    }

#    say join ' ', $b[0 .. 100];
#    say $b.subbuf(0, 100).decode('utf-8');
    die "Could not parse chunk header";
}

method make_request (
    RequestType $rt, $host, Int() $port, $path, %headers, $content?, :$ssl
) {

    my $headers = self.stringify_headers(%headers);

    # TODO https_proxy
    my ($sock, Str $req_str);
    if %*ENV<http_proxy> and !$ssl {

        my ($proxy, $proxy-port) = %*ENV<http_proxy>.split('/').[2].split(':');

        $sock = IO::Socket::INET.new(:host($proxy), :port(+($proxy-port)));

        $req_str = $rt.Stringy ~ " http://{$host}:{$port}{$path} HTTP/1.1\r\n"
        ~ $headers
        ~ "\r\n";

    }
    else {
        $sock = $ssl ?? ::('IO::Socket::SSL').new(:$host, :$port) !! IO::Socket::INET.new(:$host, :$port);

        $req_str = $rt.Stringy ~ " {$path} HTTP/1.1\r\n"
        ~ $headers
        ~ "\r\n";

    }

    # attach $content if given
    # (string context is forced by concatenation)
    $req_str ~= $content if $content.defined;

    $sock.print($req_str);

    my Blob $resp = Buf.new;

    while !self.got-header($resp) {
        $resp ~= $sock.read($default_stream_read_len);
    }

    my ($status, $resp_headers, $resp_content) = self.parse_response($resp);


    if (($resp_headers<Transfer-Encoding> || '') eq 'chunked') {
        my Bool $is_last_chunk;
        my Blob $resp_content_chunk;

        ($is_last_chunk, $resp_content) =
            self.parse_chunks($resp_content, $sock);
        while (not $is_last_chunk) {
            ($is_last_chunk, $resp_content_chunk) =
                self.parse_chunks(
                    my Blob $next_chunk_start = $sock.read(1024),
                    $sock
            );
            $resp_content ~= $resp_content_chunk;
        }
    }
    elsif ( $resp_headers<Content-Length>   &&
            $resp_content.bytes < $resp_headers<Content-Length>
    ) {
        $resp_content ~= $sock.read(
            $resp_headers<Content-Length> - $resp_content.bytes
        );
    }
    else { # a bit hacky for now but should be ok
        while ($resp.bytes > 0) {
            $resp = $sock.read($default_stream_read_len);
            $resp_content ~= $resp;
        }
    }

    $sock.close();

    return ($status, $resp_headers, $resp_content);
}

multi method get-header-end-pos(Blob:D $resp) returns Int {
    my Int $header_end_pos = 0;
    while ( $header_end_pos < $resp.bytes &&
            $http_header_end_marker ne $resp.subbuf($header_end_pos, 4)  ) {
        $header_end_pos++;
    }
    $header_end_pos;
}

multi method get-header-end-pos(Blob:U $resp) returns Int {
    0;
}

multi method got-header(Blob:D $resp) returns Bool {
    my Int $header_end_pos = self.get-header-end-pos($resp);
    return $header_end_pos > 0 && $header_end_pos < $resp.bytes
}

multi method got-header(Blob:U $resp) returns Bool {
    return False;
}

method parse_response (Blob $resp) {

    my %header;

    my Int $header_end_pos = self.get-header-end-pos($resp);

    if ($header_end_pos < $resp.bytes) {
        my @header_lines = $resp.subbuf(
            0, $header_end_pos
        ).decode('latin-1').split(/\r\n/);
        my Str $status_line = @header_lines.shift;

        for @header_lines {
            my ($name, $value) = .split(': ');
            %header{$name} = $value;
        }
        return $status_line, %header.item, $resp.subbuf($header_end_pos +4).item;
    }

    die "could not parse headers";
#    if %header.exists('Transfer-Encoding') && %header<Transfer-Encoding> ~~ m/:i chunked/ {
#        @content = self.decode_chunked(@content);
#    }

}

method getprint (Str $url, Bool :$exception ) {
    my $out = self.get($url, :$exception);
    if $out ~~ Buf { $*OUT.write($out) } else { say $out }
}

method getstore (Str $url, Str $filename, Bool :$exception ) {
    return unless defined $url;
    $filename.IO.spurt: self.get($url, :$exception ) || return
}

method parse_url (Str $url) {
    my URI $u .= new($url);
    my $path = $u.path_query;
    my $user_info = $u.userinfo;

    return (
        $u.scheme,
        $user_info ?? "{$user_info}\@{$u.host}" !! $u.host,
        $u.port,
        $path eq '' ?? '/' !! $path,
        $user_info ?? {
            host => $u.host,
            user => uri_unescape($user_info.split(':')[0]),
            password => uri_unescape($user_info.split(':')[1] || '')
        } !! Nil
    );
}

method stringify_headers (%headers) {
    my Str $str = '';
    for sort %headers.keys {
        $str ~= $_ ~ ': ' ~ %headers{$_} ~ "\r\n";
    }
    return $str;
}
