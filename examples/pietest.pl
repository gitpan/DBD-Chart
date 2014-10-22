#!/usr/bin/perl -w
use DBI;
use DBD::Chart;

$dbh = DBI->connect('dbi:Chart:');
#
#	simple piechart
#
$dbh->do('CREATE TABLE pie (region CHAR(20), sales FLOAT)');
$sth = $dbh->prepare('INSERT INTO pie VALUES( ?, ?)');
$sth->execute('East', 2756.34);
$sth->execute('Southeast', 3456.78);
$sth->execute('Midwest', 1234.56);
$sth->execute('Southwest', 4569.78);
$sth->execute('Northwest', 33456.78);

$rsth = $dbh->prepare(
"SELECT PIECHART FROM pie
	WHERE WIDTH=400 AND HEIGHT=400 AND
	TITLE = \'Sales By Region\' AND 
	COLOR=(red, green, blue, lyellow, lpurple) AND
	SIGNATURE=\'Copyright(C) 2001, GOWI Systems, Inc.\'
	AND FORMAT=\'JPEG\' AND BACKGROUND=lgray");
$rsth->execute;
$rsth->bind_col(1, \$buf);
$rsth->fetch;
open(OUTF, '>simppie.jpg');
binmode OUTF;
print OUTF $buf;
close(OUTF);

$updsth = $dbh->prepare('UPDATE pie SET sales = ? WHERE region = \'Northwest\' ');
$updsth->bind_param(1, 12999.45);
$updsth->execute;

$rsth->execute;
$rsth->bind_col(1, \$buf);
$rsth->fetch;
open(OUTF, '>updpie.png');
binmode OUTF;
print OUTF $buf;
close(OUTF);

$delsth = $dbh->prepare('delete from pie where region = ? ');
$delsth->bind_param(1, 'Northwest');
$delsth->execute;

$rsth->execute;
$rsth->bind_col(1, \$buf);
$rsth->fetch;
open(OUTF, '>delpie.png');
binmode OUTF;
print OUTF $buf;
close(OUTF);
