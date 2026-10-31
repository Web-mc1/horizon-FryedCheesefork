#!/usr/bin/env perl
# Rewrites the brand in user-facing text only: string literals and // comments.
#
# Identifiers stay as they are (SourceId::Horizon, horizon-* crates and binaries,
# HORIZON_* env vars, ~/.horizon): the launcher drives upstream builds by those names.
use strict;
use warnings;

my $B = 'crispylauncher';
local $/;

for my $file (@ARGV) {
    open my $in, '<', $file or die "rebrand: $file: $!\n";
    my $src = <$in>;
    close $in;
    my $orig = $src;

    if ($file =~ /\.(md|json)$/) {
        $src =~ s/\bHorizon\b/$B/g;
    } else {
        my $out = '';
        for my $line (split /^/m, $src) {
            # The registry-author check matches data, not display text.
            unless ($line =~ /authors\s*==/) {
                if ($line =~ m{^\s*//}) {
                    $line =~ s/\bHorizon\b/$B/g;
                } else {
                    $line = _line($line);
                }
            }
            $out .= $line;
        }
        $src = $out;
        # "crispylauncher launcher" reads redundant.
        $src =~ s/\Q$B\E launcher/$B/g;
    }

    next if $src eq $orig;

    open my $fh, '>', $file or die "rebrand: $file: $!\n";
    print {$fh} $src;
    close $fh;
    print "rebranded $file\n";
}

# Rewrites standalone "Horizon" inside the string literals of one line. Escape-aware,
# raw-string aware, and safe on literals that continue onto the next line.
sub _line {
    my ($line) = @_;
    my ($out, $i, $in, $raw) = ('', 0, 0, '');
    my $len = length $line;

    while ($i < $len) {
        my $rest = substr($line, $i);

        if (!$in && $raw eq '' && $rest =~ /^r(#+)?"/) {
            my $hashes = defined $1 ? $1 : '';
            $raw = '"' . $hashes;
            $out .= 'r' . $hashes . '"';
            $i += 2 + length $hashes;
            next;
        }

        if ($raw ne '' && substr($line, $i, length $raw) eq $raw) {
            $out .= $raw;
            $i += length $raw;
            $raw = '';
            next;
        }

        if ($raw eq '') {
            my $c = substr($line, $i, 1);
            if ($in && $c eq '\\') {
                $out .= substr($line, $i, 2);
                $i += 2;
                next;
            }
            if ($c eq '"') {
                $in = !$in;
                $out .= $c;
                $i++;
                next;
            }
        }

        if (($raw ne '' || $in) && substr($line, $i, 7) eq 'Horizon') {
            my $before = $i > 0 ? substr($line, $i - 1, 1) : '';
            my $after  = substr($line, $i + 7, 1);
            if ($before !~ /[A-Za-z0-9_]/ && $after !~ /[A-Za-z0-9_]/) {
                $out .= $B;
                $i += 7;
                next;
            }
        }

        $out .= substr($line, $i, 1);
        $i++;
    }
    return $out;
}
