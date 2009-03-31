BEGIN { 
    local $@;
    unless (eval { require Test::More; require Encode; 1 }) {
        print "1..0 # Skip need Perl 5.8 or later\n";
        exit;
    }
}

use Test::More tests => 8;
use DBI;
use Encode qw/decode/;



my @words = qw/berger Berg�re berg�re Bergere
               HOT h�te 
               h�t�roclite h�ta�re h�tre h�raut
               HAT h�ter 
               f�tu f�te f�ve ferme/;

# my @words_utf8 = map {decode("iso-8859-1", $_)} @words;
@words_utf8 = @words;
utf8::upgrade($_) foreach @words_utf8;


$" = ", "; # to embed arrays into message strings

my $dbh;
my @sorted;
my $db_sorted;
my $sql = "SELECT txt from collate_test ORDER BY txt";

sub no_accents ($$) {
    my ( $a, $b ) = map lc, @_;

    tr[����������������������������]
      [aaaaaacdeeeeiiiinoooooouuuuy] for $a, $b;

    $a cmp $b;
}



$dbh = DBI->connect("dbi:SQLite:dbname=foo", "", "", { RaiseError => 1 } );
ok($dbh);

$dbh->func( "no_accents", \&no_accents, "create_collation" );

$dbh->do( 'CREATE TEMP TABLE collate_test ( txt )' );
$dbh->do( "INSERT INTO collate_test VALUES ( '$_' )" ) foreach @words;


@sorted    = sort @words;
$db_sorted = $dbh->selectcol_arrayref("$sql COLLATE perl");
is_deeply(\@sorted, $db_sorted, "collate perl (@sorted // @$db_sorted)");

{use locale; @sorted    = sort @words;}
$db_sorted = $dbh->selectcol_arrayref("$sql COLLATE perllocale");
is_deeply(\@sorted, $db_sorted, "collate perllocale (@sorted // @$db_sorted)");

@sorted    = sort no_accents @words;
$db_sorted = $dbh->selectcol_arrayref("$sql COLLATE no_accents");
is_deeply(\@sorted, $db_sorted, "collate no_accents (@sorted // @$db_sorted)");
$dbh->disconnect;


$dbh = DBI->connect("dbi:SQLite:dbname=foo", "", "", 
                    { RaiseError => 1,
                      unicode    => 1} );
ok($dbh);
$dbh->func( "no_accents", \&no_accents, "create_collation" );
$dbh->do( 'CREATE TEMP TABLE collate_test ( txt )' );
$dbh->do( "INSERT INTO collate_test VALUES ( '$_' )" ) foreach @words_utf8;

@sorted    = sort @words_utf8;
$db_sorted = $dbh->selectcol_arrayref("$sql COLLATE perl");
is_deeply(\@sorted, $db_sorted, "collate perl (@sorted // @$db_sorted)");

{use locale; @sorted    = sort @words_utf8;}
$db_sorted = $dbh->selectcol_arrayref("$sql COLLATE perllocale");
is_deeply(\@sorted, $db_sorted, "collate perllocale (@sorted // @$db_sorted)");

@sorted    = sort no_accents @words_utf8;
$db_sorted = $dbh->selectcol_arrayref("$sql COLLATE no_accents");
is_deeply(\@sorted, $db_sorted, "collate no_accents (@sorted // @$db_sorted)");



$dbh->disconnect;
