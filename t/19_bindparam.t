#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;

use vars qw($state);

#
#   Include lib.pl
#
use vars qw($COL_NULLABLE);
do 't/lib.pl';
if ($@) {
	print STDERR "Error while executing lib.pl: $@\n";
	exit 10;
}

sub ServerError() {
    my $err = $DBI::errstr;  # Hate -w ...
    print STDERR ("Cannot connect: ", $DBI::errstr, "\n",
	"\tEither your server is not up and running or you have no\n",
	"\tpermissions for acessing the DSN 'DBI:SQLite:dbname=foo'.\n",
	"\tThis test requires a running server and write permissions.\n",
	"\tPlease make sure your server is running and you have\n",
	"\tpermissions, then retry.\n");
    exit 10;
}

if (!defined(&SQL_VARCHAR)) {
    eval "sub SQL_VARCHAR { 12 }";
}
if (!defined(&SQL_INTEGER)) {
    eval "sub SQL_INTEGER { 4 }";
}

#
#   Main loop; leave this untouched, put tests after creating
#   the new table.
#
my ($dbh, $def, $table, $cursor, $id, $name, $ref);
while (Testing()) {
    #
    #   Connect to the database
    Test($state or $dbh = DBI->connect('DBI:SQLite:dbname=foo', '', ''),
	 'connect')
	or ServerError();
    
    # For some reason this test is fscked with the utf8 flag on.
    # It seems to be because the string "K\x{00f6}nig" which to
    # me looks like unicode, should set the UTF8 flag on that
    # scalar. But no. It doesn't. Stupid fscking piece of crap.
    # (the test works if I manually set that flag with utf8::upgrade())
    # $dbh->{NoUTF8Flag} = 1 if $] > 5.007;

    #
    #   Find a possible new table name
    #
    Test($state or $table = 'table1')
	or DbiError($dbh->err, $dbh->errstr);

    #
    #   Create a new table; EDIT THIS!
    #
    Test($state or ($def = TableDefinition($table,
					   ["r_id",   "INTEGER",  4, 0],
					   ["name", "CHAR",    64, $COL_NULLABLE]) and
		    $dbh->do($def)), 'create', $def)
	or DbiError($dbh->err, $dbh->errstr);


    Test($state or $cursor = $dbh->prepare("INSERT INTO $table"
	                                   . " VALUES (?, ?)"), 'prepare')
	or DbiError($dbh->err, $dbh->errstr);

    #
    #   Insert some rows
    #

    my $konig = "Andreas K\xf6nig";
    # warn("Konig: $konig\n");

    # Automatic type detection
    my $numericVal = 1;
    my $charVal = "Alligator Descartes";
    Test($state or $cursor->execute($numericVal, $charVal), 'execute insert 1')
	or DbiError($dbh->err, $dbh->errstr);

    # Does the driver remember the automatically detected type?
    Test($state or $cursor->execute("3", "Jochen Wiedmann"),
	 'execute insert num as string')
	or DbiError($dbh->err, $dbh->errstr);
    $numericVal = 2;
    $charVal = "Tim Bunce";
    Test($state or $cursor->execute($numericVal, $charVal), 'execute insert 2')
	or DbiError($dbh->err, $dbh->errstr);

    # Now try the explicit type settings
    Test($state or $cursor->bind_param(1, " 4", SQL_INTEGER()), 'bind 1')
	or DbiError($dbh->err, $dbh->errstr);
    Test($state or $cursor->bind_param(2, $konig), 'bind 2')
	or DbiError($dbh->err, $dbh->errstr);
    Test($state or $cursor->execute, 'execute binds')
	or DbiError($dbh->err, $dbh->errstr);

    # Works undef -> NULL?
    Test($state or $cursor->bind_param(1, 5, SQL_INTEGER()))
	or DbiError($dbh->err, $dbh->errstr);
    Test($state or $cursor->bind_param(2, undef))
	or DbiError($dbh->err, $dbh->errstr);
    Test($state or $cursor->execute)
 	or DbiError($dbh->err, $dbh->errstr);


    Test($state or $cursor -> finish, 'finish');

    Test($state or undef $cursor  ||  1, 'undef cursor');

    Test($state or $dbh -> disconnect, 'disconnect');

    Test($state or undef $dbh  ||  1, 'undef dbh');

    #
    #   And now retreive the rows using bind_columns
    #
    #
    #   Connect to the database
    #
    Test($state or $dbh = DBI->connect('DBI:SQLite:dbname=foo', '', ''),
	 'connect for read')
	or ServerError();

    # $dbh->{NoUTF8Flag} = 1 if $] > 5.007;

    Test($state or $cursor = $dbh->prepare("SELECT * FROM $table"
					   . " ORDER BY abs(r_id)"))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->execute)
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->bind_columns(undef, \$id, \$name))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or ($ref = $cursor->fetch)  &&  $id == 1  &&
	 $name eq 'Alligator Descartes')
	or printf("Alligator Query returned id = %s, name = %s, ref = %s, %d\n",
		  $id, $name, $ref, scalar(@$ref));

    Test($state or (($ref = $cursor->fetch)  &&  $id == 2  &&
		    $name eq 'Tim Bunce'))
	or printf("Tim Query returned id = %s, name = %s, ref = %s, %d\n",
		  $id, $name, $ref, scalar(@$ref));

    Test($state or (($ref = $cursor->fetch)  &&  $id == 3  &&
		    $name eq 'Jochen Wiedmann'))
	or printf("Jochen Query returned id = %s, name = %s, ref = %s, %d\n",
		  $id, $name, $ref, scalar(@$ref));

    # warn("Konig: $konig\n");
    Test($state or (($ref = $cursor->fetch)  &&  $id == 4 &&
                   $name eq $konig))
	or printf("Andreas Query returned id = %s, name = %s, ref = %s, %d\n",
		  $id, $name, $ref, scalar(@$ref));

    # warn("$konig == $name ?\n");
    Test($state or (($ref = $cursor->fetch)  &&  $id == 5  &&
		    !defined($name)))
	or printf("Query returned id = %s, name = %s, ref = %s, %d\n",
		  $id, $name, $ref, scalar(@$ref));

    Test($state or undef $cursor  or  1);

    #
    #   Finally drop the test table.
    #
    Test($state or $dbh->do("DROP TABLE $table"))
	   or DbiError($dbh->err, $dbh->errstr);
}

