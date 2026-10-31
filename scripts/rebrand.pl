#!/usr/bin/env perl
# Rewrites the brand in user-facing text only: string literals and comments.
#
# Identifiers stay as they are (SourceId::Horizon, horizon-* crates and binaries,
# HORIZON_* env vars, ~/.horizon): the launcher drives upstream builds by those names.
#
# Scanning runs over the whole file rather than line by line, so a literal that
# continues onto the next line (the desktop-entry Name= and Comment= templates) is
# rebranded too. Raw strings, escapes, char literals and line comments are understood.
#
# In .md and .json every standalone word is prose or a UI string, so it is replaced
# outright; language files use the English string as the lookup key, so keys and
# values move together.
use strict;
use warnings;

my $B  = 'crispylauncher';
my $BS = chr(92);
my $NL = chr(10);
local $/;

for my $file (@ARGV) {
    open my $in, '<', $file or die "rebrand: $file: $!";
    my $src = <$in>;
    close $in;
    my $orig = $src;

    # A line ending in `// brand: keep` is left exactly as it is. Some words are data, not
    # text — the registry's own author name, a URL, a key upstream compares by value — and
    # renaming them would change what the code looks for, not what the player reads. The
    # marker protects the whole line, so write it on a line whose content stands alone.
    my @kept;
    $src =~ s/^(.*brand: keep.*)$/push @kept, $1; "\x01" . $#kept . "\x01"/gme;

    if ($file =~ /[.](md|json)$/) {
        $src =~ s/(?<![A-Za-z0-9_])Horizon(?![A-Za-z0-9_])/$B/g;
    } else {
        $src = _src($src);
        # The registry-author check matches data, not display text. Plain substitution:
        # a regex would need escaped brackets, and "[" inside a character class is a
        # single-character match, so the obvious pattern quietly does nothing.
        my $needle = 'authors == ["' . $B . '"]';
        my $repl   = 'authors == ["Horizon"]';
        my $pos    = 0;
        while (($pos = index($src, $needle, $pos)) >= 0) {
            substr($src, $pos, length $needle) = $repl;
            $pos += length $repl;
        }
        # "crispylauncher launcher" reads redundant.
        $src =~ s/$B launcher/$B/g;
    }

    $src =~ s/\x01(\d+)\x01/$kept[$1]/ge;

    next if $src eq $orig;

    open my $fh, '>', $file or die "rebrand: $file: $!";
    print {$fh} $src;
    close $fh;
    print 'rebranded ', $file, $NL;
}

# Word-boundary test at byte offset $i of $src.
sub _bound {
    my ($src, $i) = @_;
    my $before = $i > 0 ? substr($src, $i - 1, 1) : '';
    my $after  = substr($src, $i + 7, 1);
    my $ok_before = $before eq '' || $before =~ /[^A-Za-z0-9_]/;
    my $ok_after  = $after eq ''  || $after  =~ /[^A-Za-z0-9_]/;
    return $ok_before && $ok_after;
}

sub _src {
    my ($src) = @_;
    my $out = '';
    my $i   = 0;
    my $len = length $src;
    my $state   = 'code';
    my $raw_end = '';

    while ($i < $len) {
        my $c = substr($src, $i, 1);

        if ($state eq 'raw') {
            if (substr($src, $i, length $raw_end) eq $raw_end) {
                $out .= $raw_end;
                $i += length $raw_end;
                $state = 'code';
                $raw_end = '';
                next;
            }
            if (substr($src, $i, 7) eq 'Horizon' && _bound($src, $i)) {
                $out .= $B;
                $i += 7;
                next;
            }
            $out .= $c;
            $i++;
            next;
        }

        if ($state eq 'string') {
            if ($c eq $BS) {
                $out .= substr($src, $i, 2);
                $i += 2;
                next;
            }
            if ($c eq '"') {
                $state = 'code';
                $out .= $c;
                $i++;
                next;
            }
            if (substr($src, $i, 7) eq 'Horizon' && _bound($src, $i)) {
                $out .= $B;
                $i += 7;
                next;
            }
            $out .= $c;
            $i++;
            next;
        }

        if ($state eq 'line_comment') {
            if ($c eq $NL) {
                $state = 'code';
                $out .= $c;
                $i++;
                next;
            }
            if (substr($src, $i, 7) eq 'Horizon' && _bound($src, $i)) {
                $out .= $B;
                $i += 7;
                next;
            }
            $out .= $c;
            $i++;
            next;
        }

        # Code.
        my $rest = substr($src, $i);
        if ($rest =~ /^(b?r)(#+)?"/) {
            my $hashes = defined $2 ? $2 : '';
            my $prefix = $1 . $hashes . '"';
            $out .= $prefix;
            $i += length $prefix;
            $state = 'raw';
            $raw_end = '"' . $hashes;
            next;
        }
        if (substr($src, $i, 2) eq '//') {
            $state = 'line_comment';
            $out .= '//';
            $i += 2;
            next;
        }
        if ($c eq '"') {
            $state = 'string';
            $out .= $c;
            $i++;
            next;
        }
        # A char literal is copied whole, so its quote cannot open a string.
        if ($c eq "'") {
            my $j = $i + 1;
            $j += 2 if substr($src, $j, 1) eq $BS;
            $j += 1;
            $j = $len if $j > $len;
            $out .= substr($src, $i, $j - $i);
            $i = $j;
            next;
        }
        $out .= $c;
        $i++;
    }
    return $out;
}
