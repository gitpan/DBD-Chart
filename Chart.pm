#23456789012345678901234567890123456789012345678901234567890123456789012345
#
#   Copyright (c) 2001, Dean Arnold
#
#   You may distribute under the terms of the Artistic License, as 
#	specified in the Perl README file.
#
#	History:
#
#		0.50	2001-Oct-29 D. Arnold
#			Add ICON(ICONS) property
#			Add COLORS synonym
#			Add FONT property
#			Add GRIDCOLOR property
#			Add TEXTCOLOR property
#			Add Z-AXIS property
#			Add IMAGEMAP output type
#
#		0.43	2001-Oct-11 P. Scott
#			Allow a 'gif' (or any future format supported by
#			GD::Image) FORMAT and GIF logos, added use Carp.
#
#		0.42	2001-Sep-29 D. Arnold
#			fix to support X-ORIENT='HORIZONTAL' on candlestick and 
#			symbolic domains
#
#		0.41	2001-Jun-01 D. Arnold
#			fix to strip quotes from string literal in INSERT stmt
#			fix for literal data index in prepare of INSERT
#
#		0.40	2001-May-09 D. Arnold
#			fix for final column definition in CREATE TABLE
#			added Y-MIN, Y-MAX
#
#		0.21	2001-Mar-17 D. Arnold
#			Remove newlines from SQL stmts in prepare().
#
#		0.20	2001-Mar-12	D. Arnold
#			Coded.
#
require 5.6.0;
use strict;

our %mincols = ( 
'PIECHART', 2, 
'BARCHART', 2, 
'HISTOGRAM', 2,
'POINTGRAPH', 2, 
'LINEGRAPH', 2, 
'AREAGRAPH', 2, 
'CANDLESTICK', 3, 
'SURFACEMAP', 3,
'BOXCHART', 1
);

our %binary_props = (
'SHOWGRID', 1, 
'X-LOG', 1, 
'Y-LOG', 1, 
'3-D', 1, 
'SHOWPOINTS', 1, 
'SHOWVALUES', 1, 
'KEEPORIGIN', 1);
	
our %string_props = (
'X-AXIS', 1, 
'Y-AXIS', 1, 
'Z-AXIS', 1, 
'TITLE', 1, 
'SIGNATURE', 1, 
'LOGO', 1, 
'X-ORIENT', 1, 
'FORMAT', 1,
'FONT', 1,
'TEMPLATE', 1,
'MAPURL', 1,
'MAPSCRIPT', 1,
'MAPNAME', 1,
'MAPTYPE', 1
);

our %valid_props	= ( 
'SHOWVALUES', 1, 
'SHOWPOINTS', 1, 
'BACKGROUND', 1,
'KEEPORIGIN', 1, 
'SIGNATURE', 1, 
'SHOWGRID', 1, 
'X-AXIS', 1, 
'Y-AXIS', 1,
'Z-AXIS', 1, 
'TITLE', 1, 
'COLOR', 1, 
'COLORS', 1, 
'WIDTH', 1, 
'HEIGHT', 1, 
'SHAPE', 1,
'SHAPES', 1,
'X-ORIENT', 1, 
'FORMAT', 1, 
'LOGO', 1, 
'X-LOG', 1, 
'Y-LOG', 1, 
'3-D', 1,
'Y-MAX', 1, 
'Y-MIN', 1,
'ICON', 1,
'ICONS', 1,
'FONT', 1,
'TEMPLATE', 1,
'GRIDCOLOR', 1,
'TEXTCOLOR', 1,
'MAPURL', 1,
'MAPSCRIPT', 1,
'MAPNAME', 1,
'MAPTYPE', 1
);

our %valid_colors = (
	white	=> [255,255,255], 
	lgray	=> [191,191,191], 
	gray	=> [127,127,127],
	dgray	=> [63,63,63],
	black	=> [0,0,0],
	lblue	=> [0,0,255], 
	blue	=> [0,0,191],
	dblue	=> [0,0,127], 
	gold	=> [255,215,0],
	lyellow	=> [255,255,0], 
	yellow	=> [191,191,0], 
	dyellow	=> [127,127,0],
	lgreen	=> [0,255,0], 
	green	=> [0,191,0], 
	dgreen	=> [0,127,0],
	lred	=> [255,0,0], 
	red		=> [191,0,0],
	dred	=> [127,0,0],
	lpurple	=> [255,0,255], 
	purple	=> [191,0,191],
	dpurple	=> [127,0,127],
	lorange	=> [255,183,0], 
	orange	=> [255,127,0],
	pink	=> [255,183,193], 
	dpink	=> [255,105,180],
	marine	=> [127,127,255], 
	cyan	=> [0,255,255],
	lbrown	=> [210,180,140], 
	dbrown	=> [165,42,42],
	transparent => [1,1,1]
);

our @dfltcolors = qw( red green blue yellow purple orange 
dblue cyan dgreen lbrown );

our %valid_shapes = (
'fillsquare', 1,
'opensquare', 2,
'horizcross', 3,
'diagcross', 4,
'filldiamond', 5,
'opendiamond', 6,
'fillcircle', 7,
'opencircle', 8,
'icon', 9);

{
package DBD::Chart;

use DBI;

# Do NOT @EXPORT anything.
$DBD::Chart::VERSION = '0.50';

$DBD::Chart::drh = undef;
$DBD::Chart::err = 0;
$DBD::Chart::errstr = '';
$DBD::Chart::state = '00000';
%DBD::Chart::charts = ();	# defined chart list; 
							# hash of (name, property hash)
$DBD::Chart::seqno = 1;	# id for each CREATEd chart so we don't access 
						# stale names

sub driver {
#
#	if we've already been init'd, don't do it again
#
	return $DBD::Chart::drh if $DBD::Chart::drh;
	my($class, $attr) = @_;
	$class .= '::dr';
	
	$DBD::Chart::drh = DBI::_new_drh($class,
		{
			'Name' => 'Chart',
			'Version' => $DBD::Chart::VERSION,
			'Err' => \$DBD::Chart::err,
			'Errstr' => \$DBD::Chart::errstr,
			'State' => \$DBD::Chart::state,
			'Attribution' => 'DBD::Chart by Dean Arnold'
		});
	DBI->trace_msg("DBD::Chart v.$DBD::Chart::VERSION loaded on $^O\n", 1);
	return $DBD::Chart::drh;
}

1;
}

#
#	check on attributes
#
{   package DBD::Chart::dr; # ====== DRIVER ======
$DBD::Chart::dr::imp_data_size = 0;

# we use default (dummy) connect method

sub disconnect_all { }
sub DESTROY { undef }
1;
}

{   package DBD::Chart::db; # ====== DATABASE ======
    $DBD::Chart::db::imp_data_size = 0;
    use Carp;

use DBI qw(:sql_types);

my %typeval = ( 
'CHAR', SQL_CHAR, 
'VARCHAR', SQL_VARCHAR, 
'INT', SQL_INTEGER,
'SMALLINT', SQL_SMALLINT,
'TINYINT', SQL_TINYINT,
'FLOAT', SQL_FLOAT,
'DEC', SQL_DECIMAL,
'DATE', SQL_DATE,
'TIMESTAMP', SQL_TIMESTAMP,
'INTERVAL', SQL_TIMESTAMP,
'TIME', SQL_TIME);

my %typeszs = ( 
'CHAR', 1,
'VARCHAR', 32000, 
'INT', 4,
'SMALLINT', 2,
'TINYINT', 1,
'FLOAT', 8,
'DEC', 4,
'DATE', 4,
'TIMESTAMP', 26,
'INTERVAL', 26,
'TIME', 16);

my %inv_pieprop = (
'SHAPE', 1, 
'SHAPES', 1, 
'SHOWGRID', 1, 
'SHOWPOINTS', 1, 
'X-AXIS', 1, 
'Y-AXIS', 1, 
'Z-AXIS', 1, 
'SHOWVALUES', 1, 
'X-LOG', 1, 
'Y-LOG', 1, 
'Y-MAX', 1, 
'Y-MIN', 1,
'ICON', 1,
'ICONS', 1
);

my %inv_barprop = ('SHAPE', 1, 'SHAPES', 1, 'SHOWPOINTS', 1, 'X-LOG', 1);

my %inv_candle = ('X-LOG', 1, '3-D', 1);

my %dfltprops = ( 
'SHAPE', undef, 
'WIDTH', 300, 
'HEIGHT', 300,
'SHOWGRID', 0, 
'SHOWPOINTS', 0, 
'SHOWVALUES', 0, 
'X-AXIS', 'X axis', 
'Y-AXIS', 'Y axis', 
'Z-AXIS', undef, 
'TITLE', '', 
'COLORS', \@dfltcolors, 
'X-LOG', 0, 
'Y-LOG', 0, 
'3-D', 0, 
'BACKGROUND', 'white',
'SIGNATURE', undef, 
'LOGO', undef, 
'X-ORIENT', 'DEFAULT', 
'FORMAT', 'PNG',
'KEEPORIGIN', 0, 
'Y-MAX', undef, 
'Y-MIN', undef,
'ICONS', undef,
'FONT', undef,
'GRIDCOLOR', 'black',
'TEXTCOLOR', 'black',
'TEMPLATE', undef,
'MAPURL', undef,
'MAPSCRIPT', undef,
'MAPNAME', undef,
'MAPTYPE', undef
);
	
sub parse_col_defs {
	my ($req, $cols, $typeary, $typelen, $typescale) = @_;
#
#	normalize
#
	$req = uc $req;
	$req =~s/(\S),/$1 ,/g;
	$req =~s/,(\S)/, $1/g;
	$req =~s/(\S)\(/$1 \(/g;
	$req =~s/(\S)\)/$1 \)/g;
	
	$req=~s/\s+NOT\s+NULL//ig;
	$req =~s/\bLONG\s+VARCHAR\b/ VARCHAR(32000)/g;
	$req =~s/\bCHAR\s+VARYING\b/ VARCHAR/g;
	$req =~s/\bDOUBLE\s+PRECISION\b/ FLOAT /g;
	$req =~s/\bNUMERIC\b/ DEC /g;
	$req =~s/\bREAL\b/ FLOAT /g;
	$req =~s/\bCHARACTER\b/ CHAR /g;
	$req =~s/\bINTEGER\b/ INT /g;
	$req =~s/\bDECIMAL\b/ DEC /g;
#
#	normalize a bit more
#
	$req =~s/\(\s+/\(/g;
	$req =~s/\s+\)/\)/g;
	$req =~s/\((\d+)\s*\,\s*(\d+)\)/\($1\;$2\)/g;
	$req =~s/\s\((\d+)/\($1/g;
#
#	extract each declaration in the list
#
	my @reqdecs = split(',', $req);
	my $decl = '';
	my $typecnt = 0;
	my $decsz = 0;
	my $decscal = 0;
	my $name = '';
	%$cols = ();
	@$typelen = ();
	@$typeary = ();
	@$typescale = ();
	my $i = 0;
	foreach $decl (@reqdecs) {

		$_ = $decl;

		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = "Column $1 already defined.",
		return undef
			if ((/^\s*(\S+)\s+/) && ($$cols{$1}));

		$name = $1;
		$$cols{$name} = $i++;

		push(@$typelen, $typeszs{$decl}),
		push(@$typescale, 0),
		push(@$typeary, $typeval{$decl}),
		next
			if (($decl) = /^\s*\S+\s+(TIMESTAMP|SMALLINT|TINYINT|VARCHAR|FLOAT|CHAR|DATE|TIME|INT|DEC)\s*$/i);
			
		push(@$typelen, $decsz),
		push(@$typescale, 0),
		push(@$typeary, $typeval{$decl}),
		next
			if (($decl, $decsz) = /^\s*\S+\s+(VARCHAR|CHAR)\((\d+)\)\s*$/i);

		push(@$typelen, $decsz),
		push(@$typescale, 0),
		push(@$typeary, SQL_DECIMAL),
		next
			if ((($decl, $decsz) = /^\s*\S+\s+DEC\((\d+)\)\s*$/i) &&
				($decsz < 19) && ($decsz > 0));
#
#	handle scaled decimal declarations
#
		push(@$typelen, $decsz),
		push(@$typescale, $decscal),
		push(@$typeary, SQL_DECIMAL),
		next
			if ((($decl, $decsz, $decscal) = 
				/^\s*\S+\s+DEC\((\d+);(\d+)\)\s*$/i) && 
				($decsz < 19) && ($decsz > 0) && ($decscal < $decsz));

# if we get here, we've got something bogus
		$DBD::Chart::err = -1;
		$_=~s/;/,/;
		$DBD::Chart::errstr = "Invalid column definition $_"; ;
		return undef;
	}
	return $i;
}

sub parse_props {
	my ($ctype, $t, $numphs) = @_;
	
	my %props = %dfltprops;
	my $prop;
	$t .= ' AND ';
	$t=~s/''/\x01/g;	# convert escaped quote into something we can ignore
	while ($t=~/^([^\s=]+)\s*=\s*(.*)$/i) {
		$prop = uc $1;
		$t = $2;

		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = "Unrecognized property $prop.",
		return (undef, $t)
			unless $valid_props{$prop};
#
#	got a placeholder
#
		$props{ $prop } = "?$$numphs",
		$t = $1,
		$$numphs++,
		next
			if ($t=~/^\?\s+AND\s+(.*)$/i);
		
		if ($binary_props{$prop}) {
#
#	make sure its zero or 1
#
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = "Invalid value for $prop property.",
			return (undef, $t)
				if ($t!~/^(1|0)\s+AND\s+(.*)$/i);

			$props{ $prop } = $1;
			$t = $2;
			next;
		}
		if ($string_props{$prop}) {
#
#	in case it was an empty string, restore the quotes
			$t = "''" . $1 if ($t=~/^\x01(\s+AND.*)$/);
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = "$prop property requires a string.",
			return (undef, $t)
				if ($t!~/^'(.*?)'(\s+AND.*)$/);

			my $str = $1;
			$t = $2;
			$str=~s/\x01/'/g;	# restore the quotes, unescaped
			
#			$str .= '\'' . $1,
#			$t= $2
#				while ($t=~/^\'([^\']*)\'(.*)$/);

			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = "Invalid value for $prop property.",
			return (undef, $t)
				if ($t!~/^\s+AND\s+(.*)$/i);

			$t = $1;
			$props{$prop} = $str;
			next;
		}
		if (($prop eq 'WIDTH') || ($prop eq 'HEIGHT')) {
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = "Invalid value for $prop property.",
			return (undef, $t)
				if ($t!~/^(\d+)\s+AND\s+(.*)$/i);

			$props{ $prop } = $1;
			$t = $2;

			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = "Invalid value for $prop property.",
			return (undef, $t)
				if (($props{$prop} < 10) || ($props{$prop} > 100000));
			next;
		}
		if (($prop eq 'Y-MAX') || ($prop eq 'Y-MIN')) {
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = 
				"Y-MAX and Y-MIN deprecated as of release 0.50.";
			next;
		}
		if (($prop eq 'BACKGROUND') || ($prop eq 'GRIDCOLOR') || 
			($prop eq 'TEXTCOLOR')) { 
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = "Invalid value for $prop property.",
			return (undef, $t)
				unless ($t=~/^(\w+)\s+AND\s+(.*)$/i);

			$props{$prop} = lc $1;
			$t = $2;

			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = "Invalid value for $prop property.",
			return (undef, $t)
				unless $valid_colors{$props{$prop}} || 
					(($prop eq 'BACKGROUND') && ($props{$prop} eq 'transparent'));
			next;
		}
		$prop = 'COLOR' if ($prop eq 'COLORS');
		$prop = 'ICON' if ($prop eq 'ICONS');
		$prop = 'SHAPE' if ($prop eq 'SHAPES');
 		if (($prop eq 'COLOR') || ($prop eq 'SHAPE')) {
 			my @colors = ();
 			if ($t=~/^(\w+)\s+AND\s+(.*)$/i) {
 				push(@colors, lc $1);
 				$t = $2;
 			}
 			elsif ($t=~/^\(([^\)]+)\)\s+AND\s+(.*)$/i) {
 				my $c = lc $1;
 				$t = $2;
 				$c=~s/\s+//g;
 				@colors = split(',', $c);
 			}
 			else {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = "Invalid value for $prop property.";
				return (undef, $t);
			}
			$props{ $prop } = \@colors;
			next;
 		}
 		if ($prop eq 'ICON') {
 			my @icons = ();
 			if ($t=~/^'(\w+)'\s+AND\s+(.*)$/i) {
 				push(@icons, $1);
 				$t = $2;
 			}
 			elsif ($t=~/^\(([^\)]+)\)\s+AND\s+(.*)$/i) {
 				my $c = $1;
 				$t = $2;
 				$c=~s/\s+//g;
 				$c=~s/'//g;
 				@icons = split(',', $c);
 			}
 			else {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = "Invalid value for ICON property.";
				return (undef, $t);
			}
			$props{ $prop } = \@icons;
			next;
 		}
	} # end while

	if (defined($props{'COLOR'})) {
		my $colors = $props{'COLOR'};
		foreach $prop (@$colors) {
			next if $valid_colors{$prop};
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = "Unknown color $prop.",
			return (undef, $t)
		}
	}
	if (defined($props{'SHAPE'})) {
		my $colors = $props{'SHAPE'};
		foreach $prop (@$colors) {
			next if $valid_shapes{$prop};
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = "Unknown point shape $prop.";
			return (undef, $t);
		}
	}
	$DBD::Chart::err = -1,
	$DBD::Chart::errstr = "Invalid value for 'X-ORIENT' property.",
	return (undef, $t)
		if (($props{'X-ORIENT'}) && 
			($props{'X-ORIENT'}!~/^(HORIZONTAL|VERTICAL|DEFAULT)$/i));

	$DBD::Chart::err = -1,
	$DBD::Chart::errstr = "Invalid value for 'MAPTYPE' property.",
	return (undef, $t)
		if (($props{'MAPTYPE'}) && ($props{'MAPTYPE'}!~/^(HTML|PERL)$/i));

	$DBD::Chart::err = -1,
	$DBD::Chart::errstr = "Only alphanumerics and _ allowed for 'MAPNAME' property.",
	return (undef, $t)
		if (($props{'MAPNAME'}) && ($props{'MAPNAME'}=~/\W/));

	return (\%props, $t);
}

sub parse_predicate {
	my ($collist, $predcol, $predop, $predval, $numphs, $ccols, $ctypes) = @_;

	$DBD::Chart::err = -1,
	$DBD::Chart::errstr = 'Invalid predicate.',
	return undef
		unless ($collist=~/^([^\s\=<>]+)\s*(<>|<=|>=|=|>|<)\s*(.*)$/);

	my $tname = uc $1;
	$$predop = $2;
	$collist = $3;
	$$predcol = $$ccols{$tname};

	$DBD::Chart::err = -1,
	$DBD::Chart::errstr = "Unknown column $tname.",
	return undef
		unless defined($$predcol);

	$$predval = '?',
	$$numphs++,
	return 1
		if ($collist=~/^\s*\?\s*$/i);

	if ($collist=~/^([\+\-]?\d+\.\d+E[+|-]?\d+)$/i) {
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = "Invalid value for column $tname.",
		return undef
			if (($$ctypes[$$predcol] != SQL_FLOAT) && 
				($$ctypes[$$predcol] != SQL_DECIMAL));
		$$predval = $1;
		return 1;
	}
	if ($collist=~/^([\+\-]?\d+\.\d+)$/) {
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = "Invalid value for column $tname.",
		return undef
			if (($$ctypes[$$predcol] != SQL_FLOAT) && 
				($$ctypes[$$predcol] != SQL_DECIMAL));
		$$predval = $1;
		return 1;
	}
	if ($collist=~/^([\+\-]?\d+)$/) {
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = "Invalid value for column $tname.",
		return undef
			if (($$ctypes[$$predcol] == SQL_CHAR) || 
				($$ctypes[$$predcol] == SQL_VARCHAR));
		$$predval = $1;
		return 1;
	}
	if ($collist=~/^\'([^\']*)\'(.*)$/) {
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = "Invalid value for column $tname.",
		return undef
			if (($$ctypes[$$predcol] != SQL_CHAR) && 
				($$ctypes[$$predcol] != SQL_VARCHAR));

		$$predval = $1;
		$collist = $2;

		$$predval .= '\'' . $1,
		$collist= $2
			while ($collist=~/^\'([^\']*)\'(.*)$/);

		$$predval = "\'$$predval\'";
		return 1;
	}

	$DBD::Chart::err = -1;
	$DBD::Chart::errstr = 
		'Only NULL, placeholders, literal strings, and numbers allowed.';
	return undef;
}

sub prepare {
	my($dbh, $statement)= @_;
	my $i;
	my $tstmt = $statement;
	$tstmt=~s/^\s*(.+);?\s*$/$1/;
	$tstmt=~s/\n/ /g;
#
#	validate that its a CREATE, DROP, INSERT, or SELECT
#
	$DBD::Chart::err = -1,
	$DBD::Chart::errstr = 
		'Only CREATE { TABLE | CHART }, DROP { TABLE | CHART }, ' .
			'SELECT, INSERT, UPDATE, or DELETE statements supported.',
	return undef
		if ($tstmt!~/^(SELECT|CREATE|INSERT|UPDATE|DELETE|DROP)\s+(.+)$/i);

	my ($cmd, $remnant) = ($1, $2);
	$cmd = uc $cmd;
	my ($filenm, $collist, $tcols);
	if ($cmd=~/(CREATE|DROP)/) {
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 
			'Only CREATE { TABLE | CHART }, DROP { TABLE | CHART }, ' .
			'SELECT, INSERT, UPDATE, or DELETE statements supported.',
		return undef
			if ($remnant!~/^(TABLE|CHART)\s+(\w+)\s*(.*)$/i);

		($filenm, $remnant) = ($2, $3);
		$filenm = uc $filenm;

		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 
			'Unrecognized DROP statement.',
		return undef
			if (($cmd eq 'DROP') && ($remnant ne ''));
	}
	elsif ($cmd eq 'UPDATE') {
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 'Invalid UPDATE statement.',
		return undef
			unless ($remnant=~/^(\w+)\s+SET\s+(.+)$/i);

		($filenm, $remnant) = ($1, $2);
		$filenm = uc $filenm;
	}
	elsif ($cmd eq 'DELETE') {
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 'Invalid DELETE statement.',
		return undef
			unless ($remnant=~/^FROM\s+(\w+)\s*(.*)$/i);

		($filenm, $remnant) = ($1, $2);
		$filenm = uc $filenm;
		if ($remnant ne '') {
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = 'Invalid DELETE statement.',
			return undef
				unless ($remnant=~/^WHERE\s+(.+)$/i);

			$remnant = $1;
		}
	}
	elsif ($cmd eq 'INSERT') {
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 'Invalid INSERT statement.',
		return undef
			if ($remnant!~/^INTO\s+(\w+)\s+VALUES\s*\(\s*(.+)\s*\)$/i);
		($filenm, $remnant) = ($1, $2);
		$filenm = uc $filenm;
	}

	my $chart;
	if (($cmd ne 'CREATE') && ($cmd ne 'SELECT')) {
		$chart = $DBD::Chart::charts{$filenm};
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = $filenm . ' does not exist.',
		return undef
			unless $chart;
	}

	my ($ccols, $ctypes, $cprecs, $cscales);
	$ccols = $$chart{'columns'},	# a hashref (name, position)
	$ctypes = $$chart{'types'},	# an arrayref of types
	$cprecs = $$chart{'precisions'}, # an arrayref of precisions
	$cscales = $$chart{'scales'}, # an arrayref of columns
		if (($cmd eq 'UPDATE') || ($cmd eq 'INSERT') || ($cmd eq 'DELETE'));

	my %cols = ();
	my @typeary = ();
	my @typelens = ();
	my @typescale = ();

	my $numphs = 0;
	my @dtypes = ();
	my @dcharts = ();
	my @dprops = ();
	my %dversions = ();
	my %setcols = ();
	my @parmcols = ();
	my ($tname, $props, $cnum, $predicate, $ctype);
	my $imagemap = undef;
	my ($predcol, $predop, $predval) = ('','','');

	if ($cmd eq 'CREATE') {
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 
			$filenm . ' has already been CREATEd.',
		return undef
			if ($chart);

		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 
			'Unrecognized CREATE statement.',
		return undef
			if ($remnant!~/^\((.+)\)$/);

		$remnant = $1;
		my $colcnt = parse_col_defs($remnant, \%cols, \@typeary, 
			\@typelens, \@typescale);
		return undef if (! $colcnt);
	}
	elsif ($cmd eq 'DROP') { }
	elsif ($cmd eq 'INSERT') {
#
#	normalize valuelist so we can count ph's
#
		$remnant .= ',';
		$cnum = -1;
		while ($remnant ne '') {
			$cnum++;

			$remnant = $1,
			push(@parmcols, $cnum),
			$numphs++,
			next
				if ($remnant=~/^\?\s*,\s*(.*)$/);

			$remnant = $1,
			$setcols{$cnum} = undef,
			next
				if ($remnant=~/^NULL\s*,\s*(.*)$/i);

			if ($remnant=~/^([\+\-]?\d+\.\d+E[+|-]?\d+)\s*,\s*(.*)$/i) {
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = 
					"Invalid value for column type at position $cnum.",
				return undef
					if (($$ctypes[$cnum] != SQL_FLOAT) || 
						($$ctypes[$cnum] != SQL_DECIMAL));

				$remnant = $2;
				$setcols{$cnum} =  $1;
				next;
			}
			if ($remnant=~/^([\+\-]?\d+\.\d+)\s*,\s*(.*)$/) {
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = 
					"Invalid value for column type at position $cnum.",
				return undef
					if (($$ctypes[$cnum] != SQL_FLOAT) || 
						($$ctypes[$cnum] != SQL_DECIMAL));

				$remnant = $2;
				$setcols{$cnum} = $1;
				next;
			}
			if ($remnant=~/^([\+\-]?\d+)\s*,\s*(.*)$/) {
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = 
					"Invalid value for column type at position $cnum.",
				return undef
					if (($$ctypes[$cnum] == SQL_CHAR) || 
						($$ctypes[$cnum] == SQL_VARCHAR));

				$remnant = $2;
				$setcols{$cnum} = $1;
				next;
			}
			if ($remnant=~/^\'([^\']*)\'(.*)$/) {
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = 
					"Invalid value for column type at position $cnum.",
				return undef
					if (($$ctypes[$cnum] != SQL_CHAR) &&
						($$ctypes[$cnum] != SQL_VARCHAR));

				my $str = $1;
				$remnant= $2;

				$str .= '\'' . $1,
				$remnant= $2
					while ($remnant=~/^\'([^\']*)\'(.*)$/);

				$remnant=~s/^\s*,\s*//;
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = 
					"Value for column $cnum exceeds defined length.",
				return undef
					if ((($$ctypes[$cnum] == SQL_CHAR) || 
						($$ctypes[$cnum] == SQL_VARCHAR)) &&
						(length($str) > $$cprecs[$cnum]));

				$setcols{$cnum} = $str;
				next;
			}
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = 
			'Only NULL, placeholders, literal strings, and numbers allowed.';
			return undef;
		}
		$DBD::Chart::errstr = 
			'Value list does not match column definitions.',
		$DBD::Chart::err = -1,
		return undef
			if ($cnum+1 != scalar(keys(%$ccols)));
	}
	elsif ($cmd eq 'UPDATE') {
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 'Unrecognized UPDATE statement.',
		return undef
			if ($remnant!~/^(.+)\s+WHERE\s+(.+)$/i);

		$collist = $1;
		$predicate = $2;
#
#	scan SET list we can count ph's
#
		$collist .= ',';
		$tname = '';
		while ($collist ne '') {
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = 'Invalid SET clause.',
			return undef
				if ($collist!~/^([^\s\=]+)\s*\=\s*(.+)$/);

			$tname = uc $1;
			$collist = $2;
			$cnum = $$ccols{$tname};
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = 
				"Unknown column $tname in UPDATE statement.",
			return undef
				unless defined($cnum);

			if ($collist=~/^(\?|NULL)\s*,\s*(.*)$/) {
				$setcols{$cnum} = undef if ($1 ne '?');
				push(@parmcols, $cnum) if ($1 eq '?');
				$collist = $2;
				$numphs++ if ($1 eq '?');
				next;
			}
			if ($collist=~/^([\+\-]?\d+\.\d+E[+|-]?\d+)\s*,\s*(.*)$/i) {
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = "Invalid value for column $tname.",
				return undef
					if (($$ctypes[$cnum] != SQL_FLOAT) &&
						($$ctypes[$cnum] != SQL_DECIMAL));

				$setcols{$cnum} = $1;
				$collist = $2;
				next;
			}
			if ($collist=~/^([\+\-]?\d+\.\d+)\s*,\s*(.*)$/) {
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = "Invalid value for column $tname.",
				return undef
					if (($$ctypes[$cnum] != SQL_FLOAT) &&
						($$ctypes[$cnum] != SQL_DECIMAL));

				$setcols{$cnum} = $1;
				$collist = $2;
				next;
			}
			if ($collist=~/^([\+\-]?\d+)\s*,\s*(.*)$/) {
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = "Invalid value for column $tname.",
				return undef
					if (($$ctypes[$cnum] == SQL_CHAR) || 
						($$ctypes[$cnum] == SQL_VARCHAR));
				$setcols{$cnum} = $1;
				$collist = $2;
				next;
			}
			if ($collist=~/^\'([^\']*)\'(.*)$/) {
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = "Invalid value for column $tname.",
				return undef
					if (($$ctypes[$cnum] != SQL_CHAR) &&
						($$ctypes[$cnum] != SQL_VARCHAR));

				my $str = $1;
				$collist = $2;
				$str .= '\'' . $1,
				$collist= $2
					while ($collist=~/^\'([^\']*)\'(.*)$/);

				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = 
					"Value for column $i exceeds defined length.",
				return undef
					if ((($$ctypes[$cnum] == SQL_CHAR) || 
						($$ctypes[$cnum] == SQL_VARCHAR)) &&
						(length($str) > $$cprecs[$cnum]));

				$setcols{$cnum} = "\'$str\'";
				$collist=~s/^\s*,\s*//;
				next;
			}
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = 
			'Only NULL, placeholders, literal strings, and numbers allowed.';
			return undef;
		}
#
#	get predicate; only 1 allowed
#
		if ($predicate ne '') {
			return undef unless
				parse_predicate($predicate, \$predcol, \$predop, \$predval,
					\$numphs, $ccols, $ctypes);
		}
	}
	elsif ($cmd eq 'DELETE') {
#
#	get predicate; only 1 allowed
#
		return undef unless
			parse_predicate($remnant, \$predcol, \$predop, \$predval, 
				\$numphs, $ccols, $ctypes);
	}
	else {	# must be SELECT
		if ($remnant=~/^IMAGE(\s*,.+)??\s+FROM\s+(.+)$/i) {
#
#	handle layered images via derived tables
#
			my $charttype = 'IMAGE';
			$remnant = $1;
#
#	check for derived tables
#
			while ($remnant=~/^\(\s*SELECT\s+(PIECHART|BARCHART|HISTOGRAM|POINTGRAPH|LINEGRAPH|AREAGRAPH|CANDLESTICK|SURFACEMAP)\s+FROM\s+(\?|\w+)\s*(.+)$/i) {
				$ctype = uc $1;
				push(@dtypes, uc $1);
				push(@dcharts, uc $2);
				$remnant = $3;
				$filenm = uc $2;
				$chart = $DBD::Chart::charts{$filenm};

				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = $filenm . ' does not exist.',
				return undef
					unless $chart;

				$ctypes = $$chart{'types'};
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = $ctype . 
					' chart requires at least ' . 
					$mincols{$ctype} . ' columns.',
				return undef
					if (scalar(@$ctypes) < $mincols{$ctype});

				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = 
					'CANDLESTICK chart requires 2N + 1 columns.',
				return undef
					if (($ctype eq 'CANDLESTICK') && 
						((scalar(@$ctypes) - 1) & 1));

				$dversions{$filenm} = $$chart{'version'};
#
#	no global format properties, and last derived table, drop out
#
				push(@dprops, undef),
				$remnant = '',
				last
					if ($remnant=~/^\s*\)\s*$/);
#
#	no format properties, but another derived table, process it
#
				push(@dprops, undef),
				$remnant = $1,
				next
					if ($remnant=~/^\s*\)\s*,\s*(.*)$/);
#
#	no format properties, and last derived table, drop out
#
				push(@dprops, undef),
				$remnant = $1,
				last
					if ($remnant=~/^\s*\)\s*WHERE\s+(.+)$/i);

				if ($remnant=~/^\s+WHERE\s+(.+)$/i) {
#
#	process format properties for this derived table
#
					($props, $remnant) = parse_props($ctype, $1, \$numphs);
					return undef if (! $props);
					$DBD::Chart::err = -1,
					$DBD::Chart::errstr = 
						'Invalid property for derived table.',
					return undef
						if (($$props{'WIDTH'}) || ($$props{'HEIGHT'}));

					$DBD::Chart::err = -1,
					$DBD::Chart::errstr = 'Invalid derived table.',
					return undef
						if ($remnant!~/^\s*\)/);

					$remnant=~s/^\s*\)\s*//;
					push(@dprops, $props);
					last if ($remnant!~/^,\s*\(/);
					$remnant=~s/^,\s*//;
				}
			}
			if ($remnant ne '') {
				($props, $remnant) = parse_props('', $1, \$numphs);
				return undef if (! $props);
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = 
					'Invalid global property for layered image.',
				return undef
					if ($$props{'COLOR'});

				$dprops[0] = $props;
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = 'Extra text found after query.',
				return undef
					if ($remnant!~/^\s*$/);
			}
			else {
				$dprops[0] = undef
			}
		}
		elsif ($remnant=~/^(PIECHART|BARCHART|HISTOGRAM|POINTGRAPH|LINEGRAPH|AREAGRAPH|CANDLESTICK|SURFACEMAP|BOXCHART)(\s*,\s*IMAGEMAP)?\s+FROM\s+(\?|\w+)\s*(.*)$/i) {
			$ctype = uc $1;
			$imagemap = uc $2;
			$filenm = uc $3;
			$remnant = $4;
			if ($filenm ne '?') {
				$chart = $DBD::Chart::charts{$filenm};
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = $filenm . ' does not exist.',
				return undef
					unless $chart;

				$ctypes = $$chart{'types'};
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = $ctype . 
					' chart requires at least ' .
					$mincols{$ctype} . ' columns.',
				return undef
					if (scalar(@$ctypes) < $mincols{$ctype});

				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = 
					'CANDLESTICK chart requires 2N + 1 columns.',
				return undef
					if (($ctype eq 'CANDLESTICK') && 
						((scalar(@$ctypes) - 1) & 1));

				$dversions{$filenm} = $$chart{'version'};
			}
			else {
				$filenm = "?$numphs";
				$numphs++;
			}
			$imagemap = 1
				if ($imagemap);
			push(@dtypes, $ctype);
			push(@dcharts, $filenm);
			if ($remnant=~/^WHERE\s+(.+)$/i) {
#
#	process format properties
#
				($props, $remnant) = parse_props($ctype, $1, \$numphs);
				return undef if (! $props);
				push(@dprops, $props);
			}
			else {
				push(@dprops, \%dfltprops);
			}
		}
		else {
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = 'Unrecognized SELECT statement.';
			return undef;
		}
#
#	we require the file to have been CREATED
#
		foreach $filenm (@dcharts) {
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = $filenm . ' does not exist.',
			return undef
				if (($filenm!~/^\?\d+$/) && 
					(! $DBD::Chart::charts{$filenm}));
		}
	}

	my($outer, $sth) = DBI::_new_sth($dbh, {
		'Statement'     => $statement,
	});

	$sth->STORE('NUM_OF_PARAMS', $numphs);
	$sth->{'chart_dbh'} = $dbh;
	$sth->{'chart_cmd'} = $cmd;
	$sth->{'chart_name'} = $filenm;

	$sth->{'chart_precisions'} = \@typelens,
	$sth->{'chart_types'} = \@typeary,
	$sth->{'chart_scales'} = \@typescale,
	$sth->{'chart_columns'} = \%cols
		if ($cmd eq 'CREATE');

	$sth->{'chart_predicate'} = [ $predcol, $predop, $predval ]
		if ((($cmd eq 'UPDATE') || ($cmd eq 'DELETE')) && 
			(defined($predcol)));

	$sth->{'chart_version'} = $$chart{'version'},
	$sth->{'chart_param_cols'} = \@parmcols
		if (($cmd eq 'UPDATE') || ($cmd eq 'DELETE') || ($cmd eq 'INSERT'));

	$sth->{'chart_columns'} = \%setcols
		if (($cmd eq 'UPDATE') || ($cmd eq 'INSERT'));

	if ($cmd eq 'SELECT') {
		$sth->{'chart_charttypes'} = \@dtypes;
		$sth->{'chart_sources'} = \@dcharts;
		$sth->{'chart_properties'} = \@dprops;
		$sth->{'chart_version'} = \%dversions;
		$sth->{'chart_imagemap'} = $imagemap;
		if ($imagemap) {
			$sth->STORE('NUM_OF_FIELDS', 2);
			$sth->{'NAME'} = [ '', '' ];
			$sth->{'TYPE'} = [ SQL_VARBINARY, SQL_VARCHAR ];
			$sth->{'PRECISION'} = [ undef, undef ];
			$sth->{'SCALE'} = [ 0, 0 ];
			$sth->{'NULLABLE'} = [ undef, undef ];
		}
		else {
			$sth->STORE('NUM_OF_FIELDS', 1);
			$sth->{'NAME'} = [ '' ];
			$sth->{'TYPE'} = [ SQL_VARBINARY ];
			$sth->{'PRECISION'} = [ undef ];
			$sth->{'SCALE'} = [ 0 ];
			$sth->{'NULLABLE'} = [ undef ];
		}
	}

	$outer;
}

sub FETCH {
	my ($dbh, $attrib) = @_;
	return $dbh->{$attrib} if ($attrib=~/^chart_/);
	return 1 if $attrib eq 'AutoCommit';
	return $dbh->DBD::_::db::FETCH($attrib);
}

sub STORE {
	my ($dbh, $attrib, $value) = @_;
	$dbh->{$attrib} = $value and return 1 if ($attrib=~/^chart_/);
	if ($attrib eq 'AutoCommit') {
	    return 1 if $value; # is already set
	    croak("Can't disable AutoCommit");
	}
	
	return $dbh->DBD::_::db::STORE($attrib, $value);
}

sub disconnect {
	my $dbh = shift;

	$dbh->STORE(Active => 0);
	my $fname = $dbh->{'chart_name'};
	return 1 if (! $fname);
	delete $DBD::Chart::charts{$fname};

	1;
}

sub DESTROY {
#
#	close any open file here
#
	my $dbh = shift;
	$dbh->disconnect if ($dbh->{'Active'});
	1;
}

1;
}

{   package DBD::Chart::st; # ====== STATEMENT ======
use DBI qw(:sql_types);
use Carp;

$DBD::Chart::st::imp_data_size = 0;

use GD;
use DBD::Chart::Plot;

my %strpredops = (
'=', 'eq',
'<>', 'ne',
'<', 'lt',
'<=', 'le',
'>', 'gt',
'>=', 'ge'
);

my %numpredops = (
'=', '==',
'<>', '!=',
'<', '<',
'<=', '<=',
'>', '>',
'>=', '>='
);

my %numtype = (
SQL_INTEGER, 1,
SQL_SMALLINT, 1,
SQL_TINYINT, 1,
SQL_DECIMAL, 1,
SQL_FLOAT, 1
);

sub validate_properties {
	my ($props, $parms) = @_;
	foreach my $prop (keys(%$props)) {
		next if ((! $$props{$prop}) || ($$props{$prop} !~/^\?(\d+)$/));
		my $phnum = $1;
		my $t = $$parms[$phnum];
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 'Insufficient parameters provided.',
		return undef
			if ($phnum > scalar(@$parms));

		$$props{$prop} = $$parms[$phnum];

		next if (($binary_props{$prop}) && ($t=~/^(0|1)$/));

		next if ($string_props{$prop});

		next if ((($prop eq 'WIDTH') || ($prop eq 'HEIGHT')) &&
			(($t=~/^\d+$/) && ($t >= 10) && ($t <= 100000)));

		next if (($prop eq 'BACKGROUND') && ($valid_colors{$t}));

		next if (($prop eq 'X-ORIENT') && 
			($t=~/^(HORIZONTAL|VERTICAL|DEFAULT)$/i));

 		next if (($prop eq 'COLOR') && ($valid_colors{$t}));
 		
 		next if (($prop eq 'SHAPE') && ($valid_shapes{$t}));
#
#	invalid property parameter value
#
		$DBD::Chart::err = -1;
		$DBD::Chart::errstr = "Invalid value for $prop property.";
		return undef;
	}
	return 1;
}

sub execute {
	my($sth, @bind_values) = @_;
	my $parms = (@bind_values) ?
		\@bind_values : $sth->{'chart_params'};

	my ($i, $j, $k, $p, $t);
	my ($predval, $is_parmref, $data, $pctype, $is_parmary, $ttype);
	my ($paramcols, $maxary, $chart, $props, $predtype);
	my ($columns, $types, $precs, $scales, $verify, $numcols);

	my $cmd = $sth->{'chart_cmd'};
	my $dbh = $sth->{'chart_dbh'};
	my $name = $sth->{'chart_name'};
	my $typeary = $sth->{'chart_types'};
	$precs = $sth->{'chart_precisions'};
	$scales = $sth->{'chart_scales'};
	
	my $cols = $sth->{'chart_columns'}
		if ($cmd eq 'CREATE');
		
	my $setcols = $sth->{'chart_columns'}
		if (($cmd eq 'UPDATE') || ($cmd eq 'INSERT'));
		
	my $predicate = $sth->{'chart_predicate'}
		if (($cmd eq 'UPDATE') || ($cmd eq 'DELETE'));
		
	if ($cmd eq 'CREATE') {
#
#	save the description info
#
		my @ary;
		for ($i = 0; $i < scalar(keys(%$cols)); $i++) {
			my @colary = ();
			push(@ary, \@colary);
		}

		$DBD::Chart::charts{$name} = {
			'columns' => $cols,
			'types' => $typeary,
			'precisions' => $precs,
			'scales' => $scales,
			'version' => $DBD::Chart::seqno++,
			'data' => \@ary
		};
		return -1;
	}

	if ($cmd eq 'DROP') {
		$chart = $DBD::Chart::charts{$name};
		delete $$chart{'columns'};
		delete $$chart{'types'};
		delete $$chart{'precisions'};
		delete $$chart{'scales'};
		my $ary = $$chart{'data'};
		if ($ary) {
			foreach my $g (@$ary) {
				@$g = ();
			}
		}
		delete $$chart{'data'};
		delete $DBD::Chart::charts{$name};
		return -1;
	}

	my $parmsts = $sth->{'chart_parmsts'};
	if ($cmd ne 'SELECT') {
#
#	validate our chart info in case a DROP was executed
#	between prepare and execute
#
		$chart = $DBD::Chart::charts{$name};
		$DBD::Chart::errstr = "Chart $name does not exist.",
		$DBD::Chart::err = -1,
		return undef
			unless $chart;
#
#	verify that the chart versions are identical
#
		$DBD::Chart::errstr = 
			"Prepared version of $chart differs from current version.",
		$DBD::Chart::err = -1,
		return undef
			unless ($$chart{'version'} == $sth->{'chart_version'});
#
#	get the record description
#
		$columns = $$chart{'columns'};
		$types = $$chart{'types'};
		$precs = $$chart{'precisions'};
		$scales = $$chart{'scales'};
		$data = $$chart{'data'};
#
#	check for param arrays or inout params
#
		($is_parmref, $is_parmary, $maxary) = (0, 0, 1);
		$verify = ($sth->{'chart_noverify'}) ? 0 : 1;

		$DBD::Chart::errstr = 
			'Number of parameters supplied does not match number required.',
		$DBD::Chart::err = -1,
		return undef
			if (($sth->{'NUM_OF_PARAMS'}) && ((! $parms) ||
				(scalar(@$parms) != $sth->{'NUM_OF_PARAMS'})));

		$parmsts = $sth->{'chart_parmsts'};
		$predicate = $sth->{'chart_predicate'};
		$predtype = $$types[$$predicate[0]] if ($predicate);
		$paramcols = $sth->{'chart_param_cols'};
		$numcols = scalar(@$paramcols);
		if (($verify) && ($parms)) {
			$p = $$parms[0];
			$is_parmref = 1 if ((ref $$parms[0]));
			$is_parmary = 1 
				if (($is_parmref) && (ref $$parms[0] eq 'ARRAY'));
			$maxary = scalar(@$p) if ($is_parmary);
			for ($i = 1; $i < $sth->{'NUM_OF_PARAMS'}; $i++) {
				my $p = $$parms[$i];
				$DBD::Chart::errstr = 
	'All parameters must be of same type (scalar, scalarref, or arrayref).',
				$DBD::Chart::err = -1,
				return undef
				if ( (($is_parmref) && (! (ref $p) ) ) ||
					((! $is_parmref) && (ref $p)));

			
				$DBD::Chart::errstr = 
	'All parameters must be of same type (scalar, scalarref, or arrayref).',
				$DBD::Chart::err = -1,
				return undef
				if ((($is_parmary) && ((! (ref $p)) || (ref $p ne 'ARRAY'))) ||
					((! $is_parmary) && (ref $p) && (ref $p eq 'ARRAY')));
#
#	validate param arrays are consistent
#
				$DBD::Chart::errstr = 
					'All parameter arrays must be the same size.',
				$DBD::Chart::err = -1,
				return undef
					if (($is_parmary) && (scalar(@$p) != $maxary));
			}
#
#	validate param values before we apply them
#
			for ($k = 0; $k < $maxary; $k++) {
				for ($i = 0; $i < $numcols; $i++) {
					$ttype = $$types[$$paramcols[$i]];
					$p = $$parms[$i];
					$p = (($is_parmary) ? $$p[$k] : $$p) if ($is_parmref);
					next if (! defined($p));
#
#	verify param types and literals are compatible with target fields
#	NOTE: we should provide a flag to allow bypassing verification
#	for improved performance
#
					if ( ((($ttype == SQL_INTEGER) || 
						($ttype == SQL_SMALLINT) ||
						($ttype == SQL_TINYINT)) && ($p!~/^[\-\+]?\d+$/)) ||
						(($ttype == SQL_SMALLINT) && (($p <= -32767) || 
						($p >= 32767))) ||
						(($ttype == SQL_TINYINT) && 
							(($p <= -127) || ($p >= 127))) ||
						((($ttype == SQL_FLOAT) || 
							($ttype == SQL_DECIMAL)) && 
						($p!~/^[\-\+]?\d+\.\d+E[\-\+]?\d+$/) &&
						($p!~/^[\-\+]?\d+\.\d+$/) && ($p!~/^[\-\+]?\d+$/)) )
					{
						$DBD::Chart::err = -1;
						$DBD::Chart::errstr = 
	"Supplied value not compatible with target field at parameter $i.";
						if ($parmsts) {
							$$parmsts[$k] =
	"Supplied value not compatible with target field at parameter $i.",
							return undef 
								if (ref $parmsts eq 'ARRAY');
							$$parmsts{$k} = 
	"Supplied value not compatible with target field at parameter $i."
						}
						return undef;
					}
				}
#
#	predicates always come last, so they'll be last param
#
				if (($predicate) && ($$predicate[2] eq '?') && 
					($predtype != SQL_CHAR) && ($predtype != SQL_VARCHAR)) {
					$ttype = $$types[$$predicate[0]];
					$p = $$parms[$i];
					$p = (($is_parmary) ? $$p[$k] : $$p) if ($is_parmref);
#
#	verify param types and literals are compatible with target fields
#	NOTE: we should provide a flag to allow bypassing verification
#	for improved performance
#
					if (! defined($p))
					{
						$DBD::Chart::err = -1;
						$DBD::Chart::errstr = 
							'NULL values not allowed in predicates.';
						if ($parmsts) {
							$$parmsts[$k] = 
								'NULL values not allowed in predicates.',
							return undef
								if (ref $parmsts eq 'ARRAY');
							$$parmsts{$k} = 
							'NULL values not allowed in predicates.';
						}
						return undef;
					}

					if ((defined($p)) &&
						( ((($ttype == SQL_INTEGER) || 
						($ttype == SQL_SMALLINT) ||
						($ttype == SQL_TINYINT)) && ($p!~/^[\-\+]?\d+$/)) ||
						(($ttype == SQL_SMALLINT) && (($p <= -32767) || 
							($p >= 32767))) ||
						(($ttype == SQL_TINYINT) && 
							(($p <= -127) || ($p >= 127))) ||
						((($ttype == SQL_FLOAT) || 
							($ttype == SQL_DECIMAL)) && 
						($p!~/^[\-\+]?\d+\.\d+E[\-\+]?\d+$/) &&
						($p!~/^[\-\+]?\d+\.\d+$/) && ($p!~/^[\-\+]?\d+\$/)) ))
					{
						$DBD::Chart::err = -1;
						$DBD::Chart::errstr = 
		"Supplied value not compatible with target field at parameter $i.";
						if ($parmsts) {
							$$parmsts[$k] =
		"Supplied value not compatible with target field at parameter $i.",
							return undef 
								if (ref $parmsts eq 'ARRAY');
							$$parmsts{$k} = 
		"Supplied value not compatible with target field at parameter $i."
						}
						return undef;
					}
				}
			}
		}
	}
	if ($cmd eq 'INSERT') {
#
#	apply any literals
#
		foreach $i (keys(%$setcols)) {
			$t = $$data[$i];
			my $v = $$setcols{$i};
			push(@$t, (($v) x $maxary));
		}			
#
#	then apply the params
#
		for ($j = 0; $j < scalar(@$paramcols); $j++) {
			$i = $$paramcols[$j];
			$t = $$data[$i];
			$ttype = $$types[$i];
			for ($k = 0; $k < $maxary; $k++) {
#
#	merge input params and statement literals
#
				$p = $$parms[$j];
				$p = (($is_parmary) ? $$p[$k] : $$p) if ($is_parmref);

				if ((defined($p)) &&
					(($ttype == SQL_CHAR) || ($ttype == SQL_VARCHAR)) &&
					(length($p) > $$precs[$i])) {
#
#	need to push this error on the param status list (if one exists)
#
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = 
				"Supplied value truncated at parameter $j.";

					$p = substr($p, 0, $$precs[$i]);

					if ($parmsts) {
						$$parmsts[$k] = 
				"Supplied value truncated at parameter $j.", next
							if (ref $parmsts eq 'ARRAY');
						$$parmsts{$k} = 
				"Supplied value truncated at parameter $j.";
					}
				}
				push(@$t, $p);
			}
		} # end foreach value
		return $k;
	}
	
	if ($cmd eq 'UPDATE') {
#
#	check predicate to determine row numbers to update
#
		if (! $predicate) {
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = 
			'Parameter arrays not allowed for unqualified UPDATE.',
			return undef
				if ($is_parmary);
#
#	apply any literals
#
			foreach $i (keys(%$setcols)) {
				$t = $$data[$i];
				my $v = $$setcols{$i};
				$j = scalar(@$t);
				@$t = ($v) x $j;
			}
#
#	then apply params
#
			for ($j = 0; $j < scalar(@$paramcols); $j++) {
				$i = $$paramcols[$j];
				$t = $$data[$i];
				$k = scalar(@$t);
				$ttype = $$types[$i];
				$p = $$parms[$j];
				$p = $$p if ($is_parmref);

				if ((defined($p)) &&
					(($ttype == SQL_CHAR) || ($ttype == SQL_VARCHAR) ||
					($ttype == SQL_BINARY) || ($ttype == SQL_VARBINARY)) &&
					(length($p) > $$precs[$i])) {
#
#	need to push this error on the param status list (if one exists)
#
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = 
				"Supplied value truncated at parameter $j.";

					$p = substr($p, 0, $$precs[$i]);
				}
				@$t = ($p) x $k;
			}
			return 1;
		} # end if no predicate
#
#	build ary of rownums based on predicate
#
		$predval = $$predicate[2];
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 
			'Parameter arrays not allowed for literally qualified UPDATE.',
		return undef
			if (($predval ne '?') && ($is_parmary));

		my %rowmap = eval_predicate($$predicate[0], $$predicate[1], 
			$predval, $types, $data, $parms, $is_parmary, $is_parmref, 
			$maxary);

		return 0 unless scalar(%rowmap);
#
#	apply any literals
#
		my ($x, $y);
		foreach $i (keys(%$setcols)) {
			$t = $$data[$i];
			while (($x, $y) = each(%rowmap)) {
				$$t[$x] = $$setcols{$i};
			}
		}
#
#	then apply params
#
		for ($j = 0; $j < scalar(@$paramcols); $j++) {
			$i = $$paramcols[$j];
			$t = $$data[$i];
			$ttype = $$types[$i];
			while (($x, $y) = each(%rowmap)) {
				$p = $$parms[$j];
				$p = (($is_parmary) ? $$p[$y] : $$p) if ($is_parmref);
				if ((($ttype == SQL_CHAR) || ($ttype == SQL_VARCHAR) ||
					($ttype == SQL_BINARY) || ($ttype == SQL_VARBINARY)) &&
					(length($p) > $$precs[$i])) {
#
#	need to push this error on the param status list (if one exists)
#
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = 
					"Supplied value truncated at parameter $j.";

					$p = substr($p, 0, $$precs[$i]);
				}
				$$t[$x] = $p;
			}
		}
		return scalar(keys(%rowmap));
	}

	if ($cmd eq 'DELETE') {
		if (! $predicate) {
#
#	apply any literals
#
			$k = scalar(@{$$data[0]});
			foreach $t (@$data) {
				@$t = ();
			}
			return $k;
		} # end if no predicate
#
#	build ary of rownums based on predicate
#
		my %rowmap = eval_predicate($$predicate[0], $$predicate[1], 
			$$predicate[2], $types, $data, $parms, $is_parmary, 
			$is_parmref, $maxary);

		return 0 unless scalar(%rowmap);

		my @rownums = sort(keys(%rowmap));
		$j = scalar(@rownums);
		while ($k = pop(@rownums)) {
			for ($i = 0; $i < scalar(@$data); $i++) {
				$t = $$data[$i];
				splice(@$t, $k, 1);
			}
		}
		return $j;
	}
#
#	must be SELECT, so render the chart
#
	my $dtypes = $sth->{'chart_charttypes'};
	my $dcharts = $sth->{'chart_sources'};
	my $dprops = $sth->{'chart_properties'};
	my $dversions = $sth->{'chart_version'};
	my $srcsth;
	for ($i = 0; $i <= $#$dcharts; $i++) {
		$name = $$dcharts[$i];
		next if ($name eq ''); # for layered images
		$srcsth = undef;
		if ($name!~/^\?(\d+)$/) {
			$chart = $DBD::Chart::charts{$name};

			$DBD::Chart::errstr = "Chart $name does not exist.",
			$DBD::Chart::err = -1,
			return undef
				unless $chart;

			$DBD::Chart::errstr = 
			"Prepared version of $name differs from current version.",
			$DBD::Chart::err = -1,
			return undef
				if ($$chart{'version'} != $$dversions{$name});

		}
		else {	# its a parameterized chartsource
			my $phn = $1;

			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = 'Parameterized chartsource not provided.',
			return undef
				unless $$parms[$phn];

			$srcsth = $$parms[$phn];
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = 
	'Parameterized chartsource value must be a prepared and executed DBI statement handle.',
			return undef
				if (ref $srcsth ne 'DBI::st');

			my $ctype = $$dtypes[$i];
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = $ctype . ' chart requires at least ' .
				$mincols{$ctype} . ' columns.',
			return undef
				if ($srcsth->{'NUM_OF_FIELDS'} < $mincols{$ctype});

			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = 
				'CANDLESTICK chart requires 2N + 1 columns.',
			return undef
				if (($ctype eq 'CANDLESTICK') && 
					(($srcsth->{'NUM_OF_FIELDS'} - 1) & 1));
		}
	}
#
#	now we can safely process and render
#
	my $img;
	for ($i = 0; $i < scalar(@$dtypes); $i++) {
		if ($$dtypes[$i] eq 'IMAGE') {
#
#	lots of work to do here!!!
#	establish global properties
#
#	$img = DBD::Chart::Composite($$props{'WIDTH'}, $$props{'HEIGHT'});
			$i++;
		}
#
#	now synthesize a chart structure from the stmt handle
#	NOTE: we should eventually support array binding here!!!
#
		if ($$dcharts[$i]=~/^\?(\d+)$/) {
			my $srcsth = $$parms[$1];
			$columns = $srcsth->{'NAME'};
			$types = $srcsth->{'TYPE'};
			$precs = $srcsth->{'PRECISION'};
			$scales = $srcsth->{'SCALE'};
			$data = [];
			my $rowcnt = 0;
			my $row;
			foreach my $col (@$columns) {
				my @ary = ();
				push(@$data, \@ary);
			}
			
			while ($row = $srcsth->fetchrow_arrayref) {
				$rowcnt++;
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = 
	'More than 10000 plot points returned by parameterized chartsource.',
				$srcsth->finish,
				return undef
					if ($rowcnt > 10000);

				for ($j = 0; $j < $srcsth->{'NUM_OF_FIELDS'}; $j++) {
					push(@{$$data[$j]}, $$row[$j]);
				}
			}
		}
		else {
			$chart = $DBD::Chart::charts{$$dcharts[$i]};
#
#	get the record description
#
			$columns = $$chart{'columns'};
			$types = $$chart{'types'};
			$precs = $$chart{'precisions'};
			$scales = $$chart{'scales'};
			$data = $$chart{'data'};
		}

		$props = $$dprops[$i];
#
#	validate and copy in any placeholder values
#
		return undef if (! validate_properties($props, $parms));
#
#	establish color list
#
		my @colors = ();
		my $clist = ($$props{'COLOR'}) ? $$props{'COLOR'} : \@dfltcolors;
		$t = ($$dtypes[$i] eq 'PIECHART') ? scalar @{$$data[0]} : @$data;
		$t-- unless (($$dtypes[$i] eq 'BOXCHART') || ($$dtypes[$i] eq 'PIECHART'));
		$t /= 2 if ($$dtypes[$i] eq 'CANDLESTICK');
		$t = 1 if ($$props{'Z-AXIS'});
		for ($k = 0, $j = 0; $k < $t; $k++) {
			push(@colors, $$clist[$j++]);
			$j = 0 if ($j >= scalar(@$clist));
		}
#
#	create plot object
#
		$img = DBD::Chart::Plot->new($$props{WIDTH}, $$props{HEIGHT});
		return undef unless $img;
#
#	set common features
#
		$img->setOptions( title => $$props{TITLE})
			if $$props{TITLE};
				
		$img->setOptions( signature => $$props{SIGNATURE})
			if $$props{SIGNATURE};
				
		$img->setOptions( threed => $$props{'3-D'});
				
		$img->setOptions( 
			genMap => ($$props{MAPNAME}) ? $$props{MAPNAME} : 'plot', 
			mapType => $sth->{chart_imagemap},
			mapURL => $$props{MAPURL},
			mapScript => $$props{MAPSCRIPT},
			mapType => ($$props{MAPTYPE}) ? $$props{MAPTYPE} : 'HTML'
		)
			if $sth->{chart_imagemap};
				
		$img->setOptions( bgColor => $$props{BACKGROUND} );

		$img->setOptions( bgColor => $$props{BACKGROUND},
			textColor => $$props{TEXTCOLOR},
			gridColor => $$props{GRIDCOLOR} );

		$img->setOptions( logo => $$props{LOGO}) if $$props{LOGO};
		
		my $propstr = '';
#
#	Piechart:
#	first data array is domain names, the 2nd is the 
#	datasets. If more than 1 dataset is supplied, the
#	rest are ignored
#
		$propstr = 'pie ' . join(' ', @colors),
		$img->setPoints($$data[0], $$data[1], $propstr),
		$sth->{'chart_image'} = $img->plot($$props{'FORMAT'}),
		$sth->{'chart_imagemap'} = 
			($sth->{chart_imagemap}) ? $img->getMap() : undef,
		next
			if ($$dtypes[$i] eq 'PIECHART');
#
#	need column names in defined order
#
		my @colnames = ();
		if (! $srcsth) {
			foreach (keys(%$columns)) {
				$colnames[$$columns{$_}] = $_;
			}
		}
		else { 
			@colnames = @$columns;
		}
		shift @colnames unless ($$dtypes[$i] eq 'BOXCHART');

		$img->setOptions( 'xAxisLabel' => $$props{'X-AXIS'})
			if ($$props{'X-AXIS'});
		$img->setOptions( 'yAxisLabel' => $$props{'Y-AXIS'})
			if ($$props{'Y-AXIS'});
		$img->setOptions( 'zAxisLabel' => $$props{'Z-AXIS'})
			if ($$props{'Z-AXIS'});
			
		$img->setOptions( 'xAxisVert' => ($$props{'X-ORIENT'} eq 'VERTICAL'))
			if ($$props{'X-ORIENT'});
			
		$img->setOptions( 'horizGrid' => 1, 
			'vertGrid' => ($$dtypes[$i] ne 'BARCHART'))
			if ($$props{'SHOWGRID'});

		$img->setOptions( 'showValues' => 1)
			if ($$props{'SHOWVALUES'});

		$img->setOptions( 'xLog' => 1)
			if ($$props{'X-LOG'});
			
		$img->setOptions( 'yLog' => 1)
			if ($$props{'Y-LOG'});
			
		$img->setOptions( 'keepOrigin' => 1)
			if ($$props{'KEEPORIGIN'});
#
#	select domain type: numeric, symbolic, or temporal
#
		$img->setOptions( 'symDomain' => 1)
			unless $numtype{$$types[0]};
#
#	default x-axis label orientation is vertical for candlesticks
#	and symbollic domains
#
		$img->setOptions( 'xAxisVert' => ($$props{'X-ORIENT'} ne 'HORIZONTAL'))
			if ((! $numtype{$$types[0]}) || ($$dtypes[$i] eq 'CANDLESTICK'));
#
#	force a legend if more than 1 range
#
		$img->setOptions( 'legend' => \@colnames)
			if ((! $$props{'Z-AXIS'}) && 
				((($$dtypes[$i] ne 'CANDLESTICK') && (scalar(@$data) > 2)) || 
				(($$dtypes[$i] eq 'BOXCHART') && (scalar(@$data) > 1)) ||
				(scalar(@$data) > 3)));
#
#	establish icon list if any
#
		my @icons = ();
		my $iconlist = $$props{ICON};
		if ($$props{ICON}) {
			for ($k = 1, $j = 0; $k <= $#$data; $k++) {
				push(@icons, $$iconlist[$j++]);
				$j = 0 if ($j > $#$iconlist);
			}
		}
		$img->setOptions( icons => \@icons ) if ($$props{ICON});

		if ($$dtypes[$i] eq 'BARCHART') {
#
#	first data array is domain names, the rest are
#	datasets. If more than 1 dataset is supplied, then
#	bars are grouped
#
			$propstr = 'bar ';
			if ($$props{'Z-AXIS'}) {
				$img->setPoints($$data[0], $$data[1], $$data[2], 
					$propstr . $colors[0]);
			}
			else {
				for ($i=1; $i <= $#$data; $i++) {
					$img->setPoints($$data[0], $$data[$i],
						$propstr . ($$props{ICON} ? 'icon' : $colors[$i-1]));
				}
			}
			$img->plot;
			$sth->{'chart_image'} = $img->plot($$props{'FORMAT'});
			$sth->{'chart_imagemap'} = 
				($sth->{chart_imagemap}) ? $img->getMap() : undef;
			next;
		}
#
#	establish shape list, and merge with icon list if needed
#
		my @shapes = ();
		my $shapelist = ($$props{'SHAPE'}) ? $$props{'SHAPE'} : 
			[ 'fillcircle' ];
		$$props{SHOWPOINTS} = 1 if $$props{SHAPE};
		@icons = () if ($$props{ICON});
		for ($k = 1, $j = 0, my $n = 0; $k <= $#$data; $k++) {
			push(@shapes, $$shapelist[$j++]);
			push(@icons, ($$shapelist[$j-1] eq 'icon') ? $$iconlist[$n++] : undef)
				if ($$props{ICON});
			$n = 0 if ($n > $#$iconlist);
			$j = 0 if ($j > $#$shapelist);
		}
		$img->setOptions( icons => \@icons ) if ($$props{ICON});

		if ($$dtypes[$i] eq 'CANDLESTICK') {
#
#	first data array is domain symbols, the rest are
#	datasets, consisting of 2-tuples (y-min, y-max).
#	If more than 1 dataset is supplied, then sticks are grouped
#
			for (my $n = 0, $k = 1; $k <= $#$data; $k += 2, $n++) {
				$propstr = 'candle ' . $colors[$n];
				$propstr .= ' ' . $shapes[$n]
					if ($$props{'SHOWPOINTS'});
				$img->setPoints($$data[0], $$data[$k], $$data[$k+1], $propstr);
			}
			$sth->{'chart_image'} = $img->plot($$props{'FORMAT'});
			$sth->{'chart_imagemap'} = 
				($sth->{chart_imagemap}) ? $img->getMap() : undef;
			next;
		}

		if ($$dtypes[$i] eq 'BOXCHART') {
#
#	each data array is a distinct domain to be plotted
#
			for (my $n = 0, $k = 0; $k <= $#$data; $k++, $n++) {
				$propstr = 'box ' . $colors[$n];
				$propstr .= ' ' . $shapes[$n]
					if ($$props{'SHOWPOINTS'});
				$img->setPoints($$data[$k], $propstr);
			}
			$sth->{'chart_image'} = $img->plot($$props{'FORMAT'});
			$sth->{'chart_imagemap'} = 
				($sth->{chart_imagemap}) ? $img->getMap() : undef;
			next;
		}
#
#	line, point, or area graph
#
		for ($k = 1; $k <= $#$data; $k++) {
			if ($$dtypes[$i] eq 'POINTGRAPH') {
				$propstr = 'noline ' . $colors[$k-1] . ' ' . $shapes[$k-1];
			}
			elsif ($$dtypes[$i] eq 'LINEGRAPH') {
				$propstr = $colors[$k-1];
				$propstr .= ' ' . $shapes[$k-1] 
					if ($$props{'SHOWPOINTS'});
			}
			elsif ($$dtypes[$i] eq 'AREAGRAPH') {
				$propstr = 'fill ' . $colors[$k-1];
				$propstr .= ' ' . $shapes[$k-1] 
					if ($$props{'SHOWPOINTS'});
			}
			$img->setPoints($$data[0], $$data[$k], $propstr);
		}
		$sth->{chart_image} = $img->plot($$props{'FORMAT'});
		$sth->{chart_imagemap} = 
			($sth->{chart_imagemap}) ? $img->getMap() : undef;
	}
#
#	update precision values
	$precs = $sth->{PRECISION};
	$$precs[0] = length($sth->{chart_image});
	$$precs[1] = length($sth->{chart_imagemap}) if $sth->{chart_imagemap};
    return 1;
}

sub eval_predicate {
	my ($predcol, $predop, $predval, $types, $data, $parms, $is_ary, 
		$is_ref, $maxary) = @_;
	my %rowmap = ();
	my $pc = $$data[$predcol];
	my $pctype = $$types[$predcol];
	my ($i, $k, $p);
	
	if ($predval ne '?') {
		$predval=~s/^'(.+)'$/$1/;	# trim any quotes
		for ($i = 0; $i <= $#$pc; $i++) {
			$rowmap{$i} = -1
				if (((($pctype == SQL_CHAR) || ($pctype == SQL_VARCHAR)) &&
					(eval "\'$$pc[$i]\' $strpredops{$predop} \'$predval\'")) ||
					(($pctype != SQL_CHAR) && ($pctype != SQL_VARCHAR) &&
					(eval "$$pc[$i] $numpredops{$predop} $predval")));
		}
		return %rowmap;
	}
#
#	must be parameterized predicate
#
	my $parmnum = $#$parms;
	for ($k = 0; $k < $maxary; $k++) {
		$p = $$parms[$parmnum];
		$p = (($is_ary) ? $$p[$k] : $$p) if ($is_ref);
		for ($i = 0; $i <= $#$pc; $i++) {
			$rowmap{$i} = $k
				if (((($pctype == SQL_CHAR) || ($pctype == SQL_VARCHAR)) &&
					(eval "\'$$pc[$i]\' $strpredops{$predop} \'$p\'")) ||
					(($pctype != SQL_CHAR) && ($pctype != SQL_VARCHAR) &&
					(eval "$$pc[$i] $numpredops{$predop} $p")));
		}
	}
	return %rowmap;
}


sub fetch {
	my($sth) = @_;

	my $buf = $sth->{'chart_image'};
	return 0 if (! $buf);
	my @row = ($buf);
	push(@row, $sth->{chart_imagemap})
		if ($sth->{NUM_OF_FIELDS} > 1);
	return $sth->_set_fbav(\@row);
}

sub finish {
	my($sth) = @_;
}

sub bind_param {
	my ($sth, $pNum, $val, $attr) = @_;
#
#	data type for placeholders is taken from field definitions
#
	$DBD::Chart::err = -1,
	$DBD::Chart::errstr = 'Statement does not contain placeholders.',
	return undef
		unless $sth->{'NUM_OF_PARAMS'};

	my $params = $sth->{'chart_params'};
	$params = [ ],
	$sth->{'chart_params'} = $params
		unless defined($params);
	
	$$params[$pNum-1] = $val;
	1;
}
*chart_bind_param_array = \&bind_param;
*bind_param_array = \&bind_param;

sub chart_bind_param_status {
	my ($sth, $stsary) = @_;
	$DBD::Chart::err = -1,
	$DBD::Chart::errstr = 
		'bind_param_status () requires arrayref or hashref parameter.',
	return undef
		if ((ref $stsary ne 'ARRAY') && (ref $stsary ne 'HASH'));

	$sth->{'chart_paramsts'} = $stsary;
	return 1;
}
*bind_param_status = \&chart_bind_param_status;

sub bind_param_inout {
	my ($sth, $pNum, $val, $maxlen, $attr) = @_;
#
#	what do I need maxlen for ???
#
	return bind_param($sth, $pNum, $val, $attr);
}

sub STORE {
	my ($sth, $attr, $val) = @_;
	return $sth->SUPER::STORE($attr, $val) unless ($attr=~/^chart_/) ;
	$sth->{$attr} = $val;
	return 1;
}

sub FETCH {
	my($sth, $attr) = @_;
	return $sth->{$attr} if ($attr =~ /^chart_/);
	return $sth->SUPER::FETCH($attr);
}

sub DESTROY { undef }

1;
}
    __END__

=head1 NAME

DBD::Chart - DBI driver abstraction for DBD::Chart::Plot and GD::Graph

=head1 SYNOPSIS

	$dbh = DBI->connect('dbi:Chart')
	    or die "Cannot connect: " . $DBI::errstr;
	#
	#	create file if it deosn't exist, otherwise, just open
	#
	$dbh->do('CREATE TABLE mychart (name CHAR(10), ID INTEGER, value FLOAT)')
		or die $dbh->errstr;

	#	add data to be plotted
	$sth = $dbh->prepare('INSERT INTO mychart VALUES (?, ?, ?)');
	$sth->bind_param(1, 'Values');
	$sth->bind_param(2, 45);
	$sth->bind_param(2, 12345.23);
	$sth->execute or die 'Cannot execute: ' . $sth->errstr;

	#	and render it
	$sth = $dbh->prepare('SELECT BARCHART FROM mychart');
	$sth->execute or die 'Cannot execute: ' . $sth->errstr;
	@row = $sth->fetchrow_array;
	print $row[0];

	# delete the chart
	$sth = $dbh->prepare('DROP TABLE mychart')
		or die "Cannot prepare: " . $dbh->errstr;
	$sth->execute or die 'Cannot execute: ' . $sth->errstr;

	$dbh->disconnect;

=head1 WARNING

THIS IS BETA SOFTWARE.

=head1 DESCRIPTION

The DBD::Chart provides a DBI abstraction for rendering pie charts,
bar charts, and line and point graphs.

For detailed usage information, see the included L<dbdchart.html>
webpage.
See L<DBI(3)> for details on DBI.
See L<GD(3)>, L<GD::Graph(3)> for details about the graphing engines.

=head2 Prerequisites

=over 4

=item Perl 5.6.0 minimum

=item DBI 1.14 minimum

=item DBD::Chart::Plot 0.50 (included with this package)

=item GD X.XX minimum

=item GD::Text X.XX minimum

=item libpng

=item zlib

=item libgd

=item jpeg-6b

=back


=head2 Installation

For Windows users, use WinZip or similar to unpack the file, then copy
Chart.pm to wherever your site-specific modules are kept (usually
\Perl\site\lib\DBD for ActiveState Perl installations). Also create a 
'Chart' directory in the DBD directory, and copy the Plot.pm module 
to the new directory.
Note that you won't be able to execute the install test with this, but you need
a copy of 'nmake' and all its libraries to run that anyway. I may
whip up a PPM in the future.

For Unix, extract it with

    gzip -cd DBD-Chart-0.50.tar.gz | tar xf -

and then enter the following:

    cd DBD-Chart-0.50
    perl Makefile.PL
    make

Sorry, no tests are available yet. After you install, you can
run the scripts in the 'examples' subdirectory and examine the
resulting images.

    make install

Note that you probably need root or administrator permissions.
If you don't have them, read the ExtUtils::MakeMaker man page for details
on installing in your own directories. L<ExtUtils::MakeMaker>.

=head1 FOR MORE INFO

Check out http://www.presicient.com/dbdchart with your 
favorite browser.  It includes all the usage information.

=head1 AUTHOR AND COPYRIGHT

This module is Copyright (C) 2001 by Presicient Corporation

    Email: darnold@presicient.com

You may distribute this module under the terms of the Artistic 
License, as specified in the Perl README file.

=head1 SEE ALSO

L<DBI(3)>

For help on the use of DBD::Chart, see the DBI users mailing list:

  dbi-users-subscribe@perl.org

For general information on DBI see

  http://www.symbolstone.org/technology/perl/DBI

=cut
