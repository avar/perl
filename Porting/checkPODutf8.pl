#!/usr/bin/env perl
use 5.010;
use open qw< :encoding(utf8) :std >;
use autodie;
use strict;
use File::Find;
use Encode::Guess;

# Check if POD files contain non-ASCII without specifying
# =encoding. Run it as:

## perl Porting/checkPODutf8.pl

find(\&finder, '.');

sub finder {
    my $file = $_;
    return unless $file ~~ /\.pod$/;

    open my $fh, '<', $file;

    #say STDERR "Checking $file";

    next if
        # Test cases
        $file ~~ m[Pod-Simple/t];

    my ($has_enocding, @non_ascii);

    FILE: while (my $line = <$fh>) {
        chomp $line;
        if ($line ~~ /^=encoding (\S+)/) {
            $has_enocding = 1;
            last FILE;
        } elsif ($line ~~ /[^[:ascii:]]/) {
            push @non_ascii => {
                num => $.,
                line => $line,
                encoding => guess_encoding($line),
            };
        }
    }

    if (@non_ascii and not $has_enocding) {
        say "$file:";
        $DB::single = 1;
        for (@non_ascii) {
            say "    $_->{num} ($_->{encoding}{Name}?): $_->{line}";
        }
    }
}
