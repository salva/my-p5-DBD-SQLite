#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More;
use t::lib::Test;
use Fatal qw(open);

my @c_files = <*.c>, <*.xs>;
plan tests => scalar(@c_files);

FILE:
foreach my $file (@c_files) {
    open(F, $file);
    my $line = 0;
    while (<F>) {
        $line++;
        if (/^(.*)\/\//) {
            my $m = $1;
            if ($m !~ /\*/ && $m !~ /http:$/) { # skip the // in c++ comment in parse.c
                fail("C++ comment in $file line $line");
                next FILE;
            }
        }
    }
    pass("$file has no C++ comments");
    close(F);
}
