#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More;
BEGIN {
	if ( $] >= 5.008005 ) {
		plan( tests => 16 );
	} else {
		plan( skip_all => 'Unicode is not supported before 5.8.5' );
	}
}
use Test::NoWarnings;

eval "require utf8";
die $@ if $@;

my $dbh = connect_ok( unicode => 1 );
ok($dbh->func( "perl_uc", 1, \&perl_uc, "create_function" ));

ok( $dbh->do(<<'END_SQL'), 'CREATE TABLE' );
CREATE TABLE foo (
	bar varchar(255)
)
END_SQL

my @words = qw{Berg�re h�te h�ta�re h�tre};
foreach my $word (@words) {
	utf8::upgrade($word);
	ok( $dbh->do("INSERT INTO foo VALUES ( ? )", {}, $word), 'INSERT' );
	my $foo = $dbh->selectall_arrayref("SELECT perl_uc(bar) FROM foo");
	is_deeply( $foo, [ [ perl_uc($word) ] ], 'unicode upcase ok' );
	ok( $dbh->do("DELETE FROM foo"), 'DELETE ok' );
}

sub perl_uc {
	my $string = shift;
	return uc($string);
}
