#2345678901234567890123456789012345678901234567890123456789012345678901234567890
{
package DBD::Chart;

use DBI;

@EXPORT = qw(); # Do NOT @EXPORT anything.
$VERSION = '0.20';

#
#   Copyright (c) 2001, Dean Arnold
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.
#
$drh = undef;
$err = 0;
$errstr = '';
$state = '00000';
%charts = ();	#	defined chart list; hash of (name, property hash)
$seqno = 1;	# id for each CREATEd chart so we don't access stale names

sub driver {
#
#	if we've already been init'd, don't do it again
#
	return $drh if $drh;
	my($class, $attr) = @_;
	$class .= '::dr';
	
	$drh = DBI::_new_drh($class,
		{
			'Name' => 'Chart',
			'Version' => $VERSION,
			'Err' => \$DBD::Chart::err,
			'Errstr' => \$DBD::Chart::errstr,
			'State' => \$DBD::Chart::state,
			'Attribution' => 'DBD::Chart by Dean Arnold'
		});
	DBI->trace_msg("DBD::Chart v.$VERSION loaded on $^O\n", 1);
	return $drh;
}

1;
}

#
#	check on attributes
#
{   package DBD::Chart::dr; # ====== DRIVER ======
$imp_data_size = 0;
use strict;

# we use default (dummy) connect method

sub disconnect_all { }
sub DESTROY { undef }
1;
}

{   package DBD::Chart::db; # ====== DATABASE ======
    $imp_data_size = 0;
    use strict;

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

my %inv_pieprop = ('SHAPE', 1, 'SHOWGRID', 1, 
	'SHOWPOINTS', 1, 'X-AXIS', 1, 'Y-AXIS', 1, 'Z-AXIS', 1, 
	'SHOWVALUES', 1, 'X-LOG', 1, 'Y-LOG', 1);

my %inv_barprop = ('SHAPE', 1, 'SHOWPOINTS', 1, 'X-LOG', 1);

my %inv_candle = ('X-LOG', 1, '3-D', 1);

my %valid_colors = (
'white', 1,
'lgray', 1,
'gray', 1,
'dgray', 1,
'black', 1,
'lblue', 1,
'blue', 1,
'dblue', 1,
'gold', 1,
'lyellow', 1,
'yellow', 1,
'dyellow', 1,
'lgreen', 1,
'green', 1,
'dgreen', 1,
'lred', 1,
'red', 1,
'dred', 1,
'lpurple', 1,
'purple', 1,
'dpurple', 1,
'lorange', 1,
'orange', 1,
'pink', 1,
'dpink', 1,
'marine', 1,
'cyan', 1,
'lbrown', 1,
'dbrown', 1
);

my @dfltcolors = ( 'red', 'green', 'blue', 'yellow', 'purple', 'orange', 
'dblue', 'cyan', 'dgreen', 'lbrown');

my %valid_shapes = (
'fillsquare', 1,
'opensquare', 2,
'horizcross', 3,
'diagcross', 4,
'filldiamond', 5,
'opendiamond', 6,
'fillcircle', 7,
'opencircle', 8);

my %dfltprops = ( 'SHAPE', undef, 'WIDTH', 300, 'HEIGHT', 300,
	'SHOWGRID', 0, 'SHOWPOINTS', 0, 'SHOWVALUES', 0, 'X-AXIS', 'X axis', 
	'Y-AXIS', 'Y axis', 'Z-AXIS', undef, 'TITLE', '', 'COLOR', \@dfltcolors, 
	'SHAPE', undef, 'X-LOG', 0, 'Y-LOG', 0, '3-D', 0);
	
my %mincols = ( 'PIECHART', 2, 'BARCHART', 2, 'POINTGRAPH', 2, 
	'LINEGRAPH', 2, 'AREAGRAPH', 2, 'CANDLESTICK', 3, 'SURFACEMAP', 3);

sub parse_col_defs {
	my ($req, $cols, $typeary, $typelen, $typescale) = @_;
#
#	normalize
#
	$req = uc $req;
	$req =~s/(\S),/$1 ,/g;
	$req =~s/,(\S)/, $1/g;
	$req =~s/(\S)\(/$1 \(/g;
	
	$req=~s/\s+NOT\s+NULL//ig;
	$req =~s/\sLONG\s+VARCHAR/ $1/g;
	$req =~s/\sCHAR\s+VARYING/ VARCHAR/g;
	$req =~s/DOUBLE\s+PRECISION/FLOAT/g;
	$req =~s/\sNUMERIC\s/ DEC /g;
	$req =~s/\sREAL\s/ FLOAT /g;
	$req =~s/\sCHARACTER\s/ CHAR /g;
	$req =~s/\sINTEGER\s/ INT /g;
	$req =~s/\sDECIMAL\s/ DEC /g;
	$req =~s/\sBYTEINT\s/ TINYINT /g;
#
#	normalize a bit more
#
	$req =~s/\(\s+/\(/g;
	$req =~s/\s+\)/\)/g;
	$req =~s/\((\d+)\s*\,\s*(\d+)\)/\($1\;$2\)/g;
	$req =~s/\s\((\d+)/\($1/g;
#	$req =~s/\)+/\)/g;
#
#	extract each declaration in the list
#
	my @reqdecs = split(',', $req);
	my $decl = '';
	my $usingstr = '';
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

		if ((/^\s*(\S+)\s+/) && ($$cols{$1})) {
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = 
				"Column $1 already defined.";
			return undef;
		}
		$name = $1;
		$$cols{$name} = $i++;

		push(@$typelen, $typeszs{$decl}) and push(@$typescale, 0) and 
			push(@$typeary, $typeval{$decl}) and next
			if (($decl) = /^\s*\S+\s+(TIMESTAMP|SMALLINT|TINYINT|VARCHAR|FLOAT|CHAR|DATE|TIME|INT|DEC)\s*$/i);
			
		push(@$typelen, $decsz) and push(@$typescale, 0) and 
			push(@$typeary, $typeval{$decl}) and next
			if (($decl, $decsz) = /^\s*\S+\s+(VARCHAR|CHAR)\((\d+)\)\s*$/i);

		push(@$typelen, $decsz) and push(@$typescale, 0) and 
			push(@$typeary, SQL_DECIMAL) and next
			if ((($decl, $decsz) = /^\s*\S+\s+DEC\((\d+)\)\s*$/i) &&
				($decsz < 19) && ($decsz > 0));
#
#	handle scaled decimal declarations
#
		push(@$typelen, $decsz) and push(@$typescale, $decscal) and 
			push(@$typeary, SQL_DECIMAL) and next
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
	my ($ctype, $t) = @_;
	
	my %props = ();
	my $prop;
	$t .= ' AND ';
	while ($t=~/^(X-AXIS|Y-AXIS|Z-AXIS|TITLE|COLOR|WIDTH|HEIGHT|SHOWGRID|SHOWVALUES|SHAPE|SHOWPOINTS|X-LOG|Y-LOG|3-D)\s*=\s*(.*)$/i) {
		$prop = uc $1;
		$t = $2;
		if (($prop eq 'SHOWGRID') || 
			($prop eq 'X-LOG') || ($prop eq 'Y-LOG') || ($prop eq '3-D') ||
			($prop eq 'SHOWPOINTS') || ($prop eq 'SHOWVALUES')) {
			if ($t!~/^(1|0)\s+AND\s+(.*)$/i) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = "Invalid value for $prop property.";
				return undef;
			}
			$props{ $prop } = $1;
			$t = $2;
			next;
		}
		if (($prop eq 'X-AXIS') || ($prop eq 'Y-AXIS') || ($prop eq 'Z-AXIS') || ($prop eq 'TITLE')) {
			if ($t!~/^\'([^\']*)\'(.*)$/) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = 
					"$prop property requires a literal string.";
				return (undef, $t);
			}
			my $str = $1;
			$t = $2;
			while ($t=~/^\'([^\']*)\'(.*)$/) {
				$str .= '\'' . $1;
				$t= $2;
			}
			if ($t!~/^\s+AND\s+(.*)$/i) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = "Invalid value for $prop property.";
				return (undef, $t);
			}
			$t = $1;
			$props{$prop} = $str;
			next;
		}
		if (($prop eq 'WIDTH') || ($prop eq 'HEIGHT')) {
			if ($t!~/^(\d+)\s+AND\s+(.*)$/i) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = "Invalid value for $prop property.";
				return (undef, $t);
			}
			$props{ $prop } = $1;
			$t = $2;
			if (($props{$prop} < 10) || ($props{$prop} > 100000)) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = "Invalid value for $prop property.";
				return (undef, $t);
			}
			next;
		}
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
	}
#
#	validate properties for chart type
#
	if ($ctype eq 'PIECHART') {
		foreach $prop (keys(%inv_pieprop)) {
			if (defined($props{$prop})) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = "Invalid property $prop for PIECHART.";
				return (undef, $t);
			}
		}
	}
	elsif ($ctype eq 'BARCHART') {
		foreach $prop (keys(%inv_barprop)) {
			if (defined($props{$prop})) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = "Invalid property $prop for BARCHART.";
				return (undef, $t);
			}
		}
	}
	elsif ($ctype eq 'CANDLESTICK') {
		foreach $prop (keys(%inv_candle)) {
			if (defined($props{$prop})) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = "Invalid property $prop for CANDLESTICK.";
				return (undef, $t);
			}
		}
	}
	if (defined($props{'COLOR'})) {
		my $colors = $props{'COLOR'};
		foreach $prop (@$colors) {
			if (! $valid_colors{$prop}) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = "Unknown color $prop.";
				return (undef, $t);
			}
		}
	}
	if (defined($props{'SHAPE'})) {
		my $colors = $props{'SHAPE'};
		foreach $prop (@$colors) {
			if (! $valid_shapes{$prop}) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = "Unknown point shape $prop.";
				return (undef, $t);
			}
		}
	}
	return (\%props, $t);
}

sub parse_predicate {
	my ($collist, $predcol, $predop, $predval, $numphs, $ccols, $ctypes) = @_;

	if ($collist!~/^([^\s\=<>]+)\s*(<>|<=|>=|=|>|<)\s*(.*)$/) {
		$DBD::Chart::err = -1;
		$DBD::Chart::errstr = 'Invalid predicate.';
		return undef;
	}
	my $tname = uc $1;
	$$predop = $2;
	$collist = $3;
	$$predcol = $$ccols{$tname};
	if (! defined($$predcol)) {
		$DBD::Chart::err = -1;
		$DBD::Chart::errstr = "Unknown column $tname.";
		return undef;
	}
	if ($collist=~/^\s*\?\s*$/i) {
		$$predval = '?';
		$$numphs++ ;
		return 1;
	}
	if ($collist=~/^([\+\-]?\d+\.\d+E[+|-]?\d+)$/i) {
		if (($$ctypes[$$predcol] != SQL_FLOAT) && 
			($$ctypes[$$predcol] != SQL_DECIMAL)) {
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = "Invalid value for column $tname.";
			return undef;
		}
		$$predval = $1;
		return 1;
	}
	if ($collist=~/^([\+\-]?\d+\.\d+)$/) {
		if (($$ctypes[$$predcol] != SQL_FLOAT) && 
			($$ctypes[$$predcol] != SQL_DECIMAL)) {
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = "Invalid value for column $tname.";
			return undef;
		}
		$$predval = $1;
		return 1;
	}
	if ($collist=~/^([\+\-]?\d+)$/) {
		if (($$ctypes[$$predcol] == SQL_CHAR) || 
			($$ctypes[$$predcol] == SQL_VARCHAR)) {
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = "Invalid value for column $tname.";
			return undef;
		}
		$$predval = $1;
		return 1;
	}
	if ($collist=~/^\'([^\']*)\'(.*)$/) {
		if (($$ctypes[$$predcol] != SQL_CHAR) && 
			($$ctypes[$$predcol] != SQL_VARCHAR)) {
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = "Invalid value for column $tname.";
			return undef;
		}
		$$predval = $1;
		$collist = $2;
		while ($collist=~/^\'([^\']*)\'(.*)$/) {
			$$predval .= '\'' . $1;
			$collist= $2;
		}
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
#
#	validate that its a CREATE, DROP, INSERT, or SELECT
#
	if ($tstmt!~/^(SELECT|CREATE|INSERT|UPDATE|DELETE|DROP)\s+(.+)$/i) {
		$DBD::Chart::err = -1;
		$DBD::Chart::errstr = 
			'Only CREATE { TABLE | CHART }, DROP { TABLE | CHART }, ' .
				'SELECT, INSERT, UPDATE, or DELETE statements supported.';
		return undef;
	}
	my ($cmd, $remnant) = ($1, $2);
	$cmd = uc $cmd;
	my ($filenm, $collist, $tcols);
	if ($cmd=~/(CREATE|DROP)/) {
		if ($remnant!~/^(TABLE|CHART)\s+(\w+)\s*(.*)$/i) {
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = 
			'Only CREATE { TABLE | CHART }, DROP { TABLE | CHART }, ' .
				'SELECT, INSERT, UPDATE, or DELETE statements supported.';
			return undef;
		}
		($filenm, $remnant) = ($2, $3);
		$filenm = uc $filenm;
		if (($cmd eq 'DROP') && ($remnant ne '')) {
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = 
				'Unrecognized DROP statement.';
			return undef;
		}
	}
	elsif ($cmd eq 'UPDATE') {
		if ($remnant!~/^(\w+)\s+SET\s+(.+)$/i) {
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = 'Invalid UPDATE statement.';
			return undef;
		}
		($filenm, $remnant) = ($1, $2);
		$filenm = uc $filenm;
	}
	elsif ($cmd eq 'DELETE') {
		if ($remnant!~/^FROM\s+(\w+)\s*(.*)$/i) {
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = 'Invalid DELETE statement.';
			return undef;
		}
		($filenm, $remnant) = ($1, $2);
		$filenm = uc $filenm;
		if ($remnant ne '') {
			if ($remnant!~/^WHERE\s+(.+)$/i) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = 'Invalid DELETE statement.';
				return undef;
			}
			$remnant = $1;
		}
	}
	elsif ($cmd eq 'INSERT') {
		if ($remnant!~/^INTO\s+(\w+)\s+VALUES\s*\(\s*(.+)\s*\)$/i) {
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = 'Invalid INSERT statement.';
			return undef;
		}
		($filenm, $remnant) = ($1, $2);
		$filenm = uc $filenm;
	}

	my $chart;
	if (($cmd ne 'CREATE') && ($cmd ne 'SELECT')) {
		$chart = $DBD::Chart::charts{$filenm};
		if (! $chart) {
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = $filenm . ' does not exist.';
			return undef;
		}
	}

	my ($ccols, $ctypes, $cprecs, $cscales);
	if (($cmd eq 'UPDATE') || ($cmd eq 'INSERT') || ($cmd eq 'DELETE')) {
		$ccols = $$chart{'columns'};	# a hashref (name, position)
		$ctypes = $$chart{'types'};	# an arrayref of types
		$cprecs = $$chart{'precisions'}; # an arrayref of precisions
		$cscales = $$chart{'scales'}; # an arrayref of columns
	}

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
	my ($predcol, $predop, $predval) = ('','','');

	if ($cmd eq 'CREATE') {
		if ($chart) {
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = 
				$filenm . ' has already been CREATEd.';
			return undef;
		}
		if ($remnant!~/^\((.+)\)$/) {
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = 
				'Unrecognized CREATE statement.';
			return undef;
		}
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
			if ($remnant=~/^\?\s*,\s*(.*)$/) {
				$remnant = $1;
				push(@parmcols, $cnum);
				$numphs++;
				next;
			}
			if ($remnant=~/^NULL\s*,\s*(.*)$/i) {
				$remnant = $1;
				$setcols{$cnum} = undef;
				next;
			}
			if ($remnant=~/^([\+\-]?\d+\.\d+E[+|-]?\d+)\s*,\s*(.*)$/i) {
				if (($$ctypes[$cnum] != SQL_FLOAT) || 
					($$ctypes[$cnum] != SQL_DECIMAL)) {
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = 
					"Invalid value for column type at position $cnum.";
					return undef;
				}
				$remnant = $2;
				$setcols{$cnum} =  $1;
				next;
			}
			if ($remnant=~/^([\+\-]?\d+\.\d+)\s*,\s*(.*)$/) {
				if (($$ctypes[$cnum] != SQL_FLOAT) || 
					($$ctypes[$cnum] != SQL_DECIMAL)) {
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = 
					"Invalid value for column type at position $cnum.";
					return undef;
				}
				$remnant = $2;
				$setcols{$cnum} = $1;
				next;
			}
			if ($remnant=~/^([\+\-]?\d+)\s*,\s*(.*)$/) {
				if (($$ctypes[$cnum] == SQL_CHAR) || 
					($$ctypes[$cnum] == SQL_VARCHAR)) {
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = 
					"Invalid value for column type at position $cnum.";
					return undef;
				}
				$remnant = $2;
				$setcols{$cnum} = $1;
				next;
			}
			if ($remnant=~/^\'([^\']*)\'(.*)$/) {
				if (($$ctypes[$cnum] != SQL_CHAR) &&
					($$ctypes[$cnum] != SQL_VARCHAR)) {
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = 
					"Invalid value for column type at position $cnum.";
					return undef;
				}
				my $str = $1;
				$remnant= $2;
				while ($remnant=~/^\'([^\']*)\'(.*)$/) {
					$str .= '\'' . $1;
					$remnant= $2;
				}
				$remnant=~s/^\s*,\s*//;
				if ((($$ctypes[$i] == SQL_CHAR) || 
					($$ctypes[$i] == SQL_VARCHAR)) &&
					(length($str) > $$cprecs[$i])) {
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = 
					"Value for column $i exceeds defined length.";
					return undef;
				}
				$setcols{$cnum} = "\'$str\'";
				next;
			}
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = 
			'Only NULL, placeholders, literal strings, and numbers allowed.';
			return undef;
		}
		if ($cnum+1 != scalar(keys(%$ccols))) {
			$DBD::Chart::errstr = 
				'Value list does not match column definitions.';
			$DBD::Chart::err = -1;
			return undef;
		}
	}
	elsif ($cmd eq 'UPDATE') {
		if ($remnant!~/^(.+)\s+WHERE\s+(.+)$/i) {
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = 'Unrecognized UPDATE statement.';
			return undef;
		}
		$collist = $1;
		$predicate = $2;
#
#	scan SET list we can count ph's
#
		$collist .= ',';
		$tname = '';
		while ($collist ne '') {
			if ($collist!~/^([^\s\=]+)\s*\=\s*(.+)$/) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = 'Invalid SET clause.';
				return undef;
			}
			$tname = uc $1;
			$collist = $2;
			$cnum = $$ccols{$tname};
			if (! defined($cnum)) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = 
					"Unknown column $tname in UPDATE statement.";
				return undef;
			}
			if ($collist=~/^(\?|NULL)\s*,\s*(.*)$/) {
				$setcols{$cnum} = undef if ($1 ne '?');
				push(@parmcols, $cnum) if ($1 eq '?');
				$collist = $2;
				$numphs++ if ($1 eq '?');
				next;
			}
			if ($collist=~/^([\+\-]?\d+\.\d+E[+|-]?\d+)\s*,\s*(.*)$/i) {
				if (($$ctypes[$cnum] != SQL_FLOAT) &&
					($$ctypes[$cnum] != SQL_DECIMAL)) {
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = "Invalid value for column $tname.";
					return undef;
				}
				$setcols{$cnum} = $1;
				$collist = $2;
				next;
			}
			if ($collist=~/^([\+\-]?\d+\.\d+)\s*,\s*(.*)$/) {
				if (($$ctypes[$cnum] != SQL_FLOAT) &&
					($$ctypes[$cnum] != SQL_DECIMAL)) {
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = "Invalid value for column $tname.";
					return undef;
				}
				$setcols{$cnum} = $1;
				$collist = $2;
				next;
			}
			if ($collist=~/^([\+\-]?\d+)\s*,\s*(.*)$/) {
				if (($$ctypes[$cnum] == SQL_CHAR) || 
					($$ctypes[$cnum] == SQL_VARCHAR)) {
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = "Invalid value for column $tname.";
					return undef;
				}
				$setcols{$cnum} = $1;
				$collist = $2;
				next;
			}
			if ($collist=~/^\'([^\']*)\'(.*)$/) {
				if (($$ctypes[$cnum] != SQL_CHAR) &&
					($$ctypes[$cnum] != SQL_VARCHAR)) {
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = "Invalid value for column $tname.";
					return undef;
				}
				my $str = $1;
				$collist = $2;
				while ($collist=~/^\'([^\']*)\'(.*)$/) {
					$str .= '\'' . $1;
					$collist= $2;
				}
				if ((($$ctypes[$cnum] == SQL_CHAR) || 
					($$ctypes[$cnum] == SQL_VARCHAR)) &&
					(length($str) > $$cprecs[$cnum])) {
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = 
						"Value for column $i exceeds defined length.";
					return undef;
				}
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
		if ($remnant=~/^IMAGE\s+FROM\s+(.+)$/i) {
#
#	handle layered images via derived tables
#
			my $charttype = 'IMAGE';
			$remnant = $1;
#
#	check for derived tables
#
			while ($remnant=~/^\(\s*SELECT\s+(PIECHART|BARCHART|POINTGRAPH|LINEGRAPH|AREAGRAPH|CANDLESTICK|SURFACEMAP)\s+FROM\s+(\w+)\s*(.+)$/i) {
				$ctype = uc $1;
				push(@dtypes, uc $1);
				push(@dcharts, uc $2);
				$remnant = $3;
				$filenm = uc $2;
				$chart = $DBD::Chart::charts{$filenm};
				if (! $chart) {
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = $filenm . ' does not exist.';
					return undef;
				}
				$ctypes = $$chart{'types'};
				if (scalar(@$ctypes) < $mincols{$ctype}) {
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = $ctype . ' chart requires at least ' . $mincols{$ctype} . ' columns.';
					return undef;
				}
				if (($ctype eq 'CANDLESTICK') && ((scalar(@$ctypes) - 1) & 1)) {
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = 'CANDLESTICK chart requires 2N + 1 columns.';
					return undef;
				}

				$dversions{$filenm} = $$chart{'version'};
				if ($remnant=~/^\s*\)\s*$/) {
#
#	no global format properties, and last derived table, drop out
#
					push(@dprops, undef);
					$remnant = '';
					last;
				}
				if ($remnant=~/^\s*\)\s*,\s*(.*)$/) {
#
#	no format properties, but another derived table, process it
#
					push(@dprops, undef);
					$remnant = $1;
					next;
				}
				if ($remnant=~/^\s*\)\s*WHERE\s+(.+)$/i) {
#
#	no format properties, and last derived table, drop out
#
					push(@dprops, undef);
					$remnant = $1;
					last;
				}
				if ($remnant=~/^\s+WHERE\s+(.+)$/i) {
#
#	process format properties for this derived table
#
					($props, $remnant) = parse_props($ctype, $1);
					return undef if (! $props);
					if (($$props{'WIDTH'}) || ($$props{'HEIGHT'})) {
						$DBD::Chart::err = -1;
						$DBD::Chart::errstr = 
					'Invalid property for derived table.';
						return undef;
					}
					if ($remnant!~/^\s*\)/) {
						$DBD::Chart::err = -1;
						$DBD::Chart::errstr = 'Invalid derived table.';
						return undef;
					}
					$remnant=~s/^\s*\)\s*//;
					push(@dprops, $props);
					last if ($remnant!~/^,\s*\(/);
					$remnant=~s/^,\s*//;
				}
			}
			if ($remnant ne '') {
				($props, $remnant) = parse_props('', $1);
				return undef if (! $props);
				if ($$props{'COLOR'}) {
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = 
						'Invalid global property for layered image.';
					return undef;
				}
				$dprops[0] = $props;
				if ($remnant!~/^\s*$/) {
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = 'Extra text found after query.';
					return undef;
				}
			}
			else {
				$dprops[0] = undef;
			}
		}
		elsif ($remnant=~/^(PIECHART|BARCHART|POINTGRAPH|LINEGRAPH|AREAGRAPH|CANDLESTICK|SURFACEMAP)\s+FROM\s+(\w+)\s*(.*)$/i) {
			$ctype = uc $1;
			push(@dtypes, uc $1);
			push(@dcharts, uc $2);
			$remnant = $3;
			$filenm = uc $2;
			$chart = $DBD::Chart::charts{$filenm};
			if (! $chart) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = $filenm . ' does not exist.';
				return undef;
			}
			$ctypes = $$chart{'types'};
			if (scalar(@$ctypes) < $mincols{$ctype}) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = $ctype . ' chart requires at least ' . $mincols{$ctype} . ' columns.';
				return undef;
			}
			if (($ctype eq 'CANDLESTICK') && ((scalar(@$ctypes) - 1) & 1)) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = 'CANDLESTICK chart requires 2N + 1 columns.';
				return undef;
			}
			$dversions{$filenm} = $$chart{'version'};
			if ($remnant=~/^WHERE\s+(.+)$/i) {
#
#	process format properties
#
				($props, $remnant) = parse_props($ctype, $1);
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
			if (! $DBD::Chart::charts{$filenm}) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = $filenm . ' does not exist.';
				return undef;
			}
		}
	}

	my($outer, $sth) = DBI::_new_sth($dbh, {
		'Statement'     => $statement,
	});

	$numphs = scalar(@parmcols) + ((($predval) && ($predval eq '?')) ? 1 : 0);
	$sth->STORE('NUM_OF_PARAMS', $numphs);
	$sth->{'chart_dbh'} = $dbh;
	$sth->{'chart_cmd'} = $cmd;
	$sth->{'chart_name'} = $filenm;
	$sth->{'chart_precisions'} = \@typelens and
		$sth->{'chart_types'} = \@typeary and
		$sth->{'chart_scales'} = \@typescale and
		$sth->{'chart_columns'} = \%cols
		if ($cmd eq 'CREATE');

	$sth->{'chart_predicate'} = [ $predcol, $predop, $predval ]
		if ((($cmd eq 'UPDATE') || ($cmd eq 'DELETE')) && 
			(defined($predcol)));

	$sth->{'chart_version'} = $$chart{'version'} and
		$sth->{'chart_param_cols'} = \@parmcols
		if (($cmd eq 'UPDATE') || ($cmd eq 'DELETE') || ($cmd eq 'INSERT'));

	$sth->{'chart_columns'} = \%setcols
		if (($cmd eq 'UPDATE') || ($cmd eq 'INSERT'));

	if ($cmd eq 'SELECT') {
		$sth->STORE('NUM_OF_FIELDS', 1);
		$sth->{'NAME'} = '';
		$sth->{'TYPE'} = SQL_VARBINARY;
		$sth->{'PRECISION'} = undef;
		$sth->{'SCALE'} = 0;
		$sth->{'NULLABLE'} = undef;
		$sth->{'chart_charttypes'} = \@dtypes;
		$sth->{'chart_sources'} = \@dcharts;
		$sth->{'chart_properties'} = \@dprops;
		$sth->{'chart_version'} = \%dversions;
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

$imp_data_size = 0;
use strict;

use GD;
use GD::Graph::pie;
use GD::Graph::bars;
use GD::Graph::bars3d;
use DBD::Chart::Plot;

my %colors = (
'white', 1,
'lgray', 1,
'gray', 1,
'dgray', 1,
'black', 1,
'lblue', 1,
'blue', 1,
'dblue', 1,
'gold', 1,
'lyellow', 1,
'yellow', 1,
'dyellow', 1,
'lgreen', 1,
'green', 1,
'dgreen', 1,
'lred', 1,
'red', 1,
'dred', 1,
'lpurple', 1,
'purple', 1,
'dpurple', 1,
'lorange', 1,
'orange', 1,
'pink', 1,
'dpink', 1,
'marine', 1,
'cyan', 1,
'lbrown', 1,
'dbrown', 1
);

my @dfltcolors = ( 'red', 'green', 'blue', 'yellow', 'purple', 'orange', 
'dblue', 'cyan', 'dgreen', 'lbrown');

my %shapes = (
'fillsquare', 1,
'opensquare', 2,
'horizcross', 3,
'diagcross', 4,
'filldiamond', 5,
'opendiamond', 6,
'fillcircle', 7,
'opencircle', 8);

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
		if (! $chart) {
			$DBD::Chart::errstr = "Chart $name does not exist.";
			$DBD::Chart::err = -1;
			return undef;
		}
#
#	verify that the chart versions are identical
#
		if ($$chart{'version'} != $sth->{'chart_version'}) {
			$DBD::Chart::errstr = 
			"Prepared version of $chart differs from current version.";
			$DBD::Chart::err = -1;
			return undef;
		}
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
		if (($sth->{'NUM_OF_PARAMS'}) && ((! $parms) ||
			(scalar(@$parms) != $sth->{'NUM_OF_PARAMS'}))) {
			$DBD::Chart::errstr = 
			'Number of parameters supplied does not match number required.';
			$DBD::Chart::err = -1;
			return undef;
		}
		$parmsts = $sth->{'chart_parmsts'};
		$predicate = $sth->{'chart_predicate'};
		$predtype = $$types[$$predicate[0]] if ($predicate);
		$paramcols = $sth->{'chart_param_cols'};
		$numcols = scalar(@$paramcols);
		if (($verify) && ($parms)) {
			$p = $$parms[0];
			$is_parmref = 1 if ((ref $$parms[0]));
			$is_parmary = 1 if (($is_parmref) && (ref $$parms[0] eq 'ARRAY'));
			$maxary = scalar(@$p) if ($is_parmary);
			for ($i = 1; $i < $sth->{'NUM_OF_PARAMS'}; $i++) {
				my $p = $$parms[$i];
				if ( (($is_parmref) && (! (ref $p) ) ) ||
					((! $is_parmref) && (ref $p))) {
					$DBD::Chart::errstr = 
	'All parameters must be of same type (scalar, scalarref, or arrayref).';
					$DBD::Chart::err = -1;
					return undef;
				}
			
				if ((($is_parmary) && ((! (ref $p)) || (ref $p ne 'ARRAY'))) ||
					((! $is_parmary) && (ref $p) && (ref $p eq 'ARRAY'))) {
					$DBD::Chart::errstr = 
	'All parameters must be of same type (scalar, scalarref, or arrayref).';
					$DBD::Chart::err = -1;
					return undef;
				}
#
#	validate param arrays are consistent
#
				if (($is_parmary) && (scalar(@$p) != $maxary)) {
					$DBD::Chart::errstr = 
						'All parameter arrays must be the same size.';
					$DBD::Chart::err = -1;
					return undef;
				}
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
					if ( ((($ttype == SQL_INTEGER) || ($ttype == SQL_SMALLINT) ||
						($ttype == SQL_TINYINT)) && ($p!~/^[\-\+]?\d+$/)) ||
						(($ttype == SQL_SMALLINT) && (($p <= -32767) || 
							($p >= 32767))) ||
						(($ttype == SQL_TINYINT) && (($p <= -127) || ($p >= 127))) ||
						((($ttype == SQL_FLOAT) || ($ttype == SQL_DECIMAL)) && 
						($p!~/^[\-\+]?\d+\.\d+E[\-\+]?\d+$/) &&
						($p!~/^[\-\+]?\d+\.\d+$/) && ($p!~/^[\-\+]?\d+$/)) )
					{
						$DBD::Chart::err = -1;
						$DBD::Chart::errstr = 
				"Supplied value not compatible with target field at parameter $i.";
						if ($parmsts) {
							$$parmsts[$k] =
				"Supplied value not compatible with target field at parameter $i." and
								return undef if (ref $parmsts eq 'ARRAY');
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
							if (ref $parmsts eq 'ARRAY') {
								$$parmsts[$k] = 
									'NULL values not allowed in predicates.';
								return undef ;
							}
							$$parmsts{$k} = 
							'NULL values not allowed in predicates.';
						}
						return undef;
					}

					if ((defined($p)) &&
						( ((($ttype == SQL_INTEGER) || ($ttype == SQL_SMALLINT) ||
						($ttype == SQL_TINYINT)) && ($p!~/^[\-\+]?\d+$/)) ||
						(($ttype == SQL_SMALLINT) && (($p <= -32767) || 
							($p >= 32767))) ||
						(($ttype == SQL_TINYINT) && (($p <= -127) || ($p >= 127))) ||
						((($ttype == SQL_FLOAT) || ($ttype == SQL_DECIMAL)) && 
						($p!~/^[\-\+]?\d+\.\d+E[\-\+]?\d+$/) &&
						($p!~/^[\-\+]?\d+\.\d+$/) && ($p!~/^[\-\+]?\d+\$/)) ))
					{
						$DBD::Chart::err = -1;
						$DBD::Chart::errstr = 
			"Supplied value not compatible with target field at parameter $i.";
						if ($parmsts) {
							$$parmsts[$k] =
			"Supplied value not compatible with target field at parameter $i."
								and return undef 
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
				"Supplied value truncated at parameter $j." and next
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
			if ($is_parmary) {
				$DBD::Chart::err = -1;
				$DBD::Chart::errstr = 
				'Parameter arrays not allowed for unqualified UPDATE.';
				return undef;
			}
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
		if (($predval ne '?') && ($is_parmary)) {
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = 
				'Parameter arrays not allowed for literally qualified UPDATE.';
			return undef;
		}
		my %rowmap = eval_predicate($$predicate[0], $$predicate[1], $predval, 
			$types, $data, $parms, $is_parmary, $is_parmref, $maxary);

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
		my %rowmap = eval_predicate($$predicate[0], $$predicate[1], $$predicate[2], 
			$types, $data, $parms, $is_parmary, $is_parmref, $maxary);

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
	foreach $name (@$dcharts) {
		next if ($name eq ''); # for layered images
		$chart = $DBD::Chart::charts{$name};
		if (! $chart) {
			$DBD::Chart::errstr = "Chart $name does not exist.";
			$DBD::Chart::err = -1;
			return undef;
		}
		if ($$chart{'version'} != $$dversions{$name}) {
			$DBD::Chart::errstr = 
		"Prepared version of $name differs from current version.";
			$DBD::Chart::err = -1;
			return undef;
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
#			$img = DBD::Chart::Composite($$props{'WIDTH'}, $$props{'HEIGHT'});
			$i++;
		}
		$chart = $DBD::Chart::charts{$$dcharts[$i]};
		$props = $$dprops[$i];
#
#	get the record description
#
		$columns = $$chart{'columns'};
		$types = $$chart{'types'};
		$precs = $$chart{'precisions'};
		$scales = $$chart{'scales'};
		$data = $$chart{'data'};
		if ($$dtypes[$i] eq 'PIECHART') {
#
#	first data array is domain names, the 2nd is the 
#	datasets. If more than 1 dataset is supplied, the
#	rest are ignored
#
			my @colors = ();
			my $clist = ($$props{'COLOR'}) ? $$props{'COLOR'} : \@dfltcolors;
			$t = $$data[0];
			for ($k = 0, $j = 0; $k < scalar(@$t); $k++) {
				push(@colors, $$clist[$j++]);
				$j = 0 if ($j >= scalar(@$clist));
			}
			$img = GD::Graph::pie->new($$props{'WIDTH'}, $$props{'HEIGHT'});

			$img->set( title => $$props{'TITLE'})
				if ($$props{'TITLE'});
				
			$img->set( '3d' => 0)
				if (! $$props{'3-D'});
				
			$img->set_title_font(gdLargeFont);
			$img->set_value_font(gdSmallFont);

			$img->set( 
				suppress_angle => 5, 
				transparent => 0,
				dclrs => \@colors
			);

			$img->plot($data);
			$sth->{'chart_image'} = $img->gd->png();
			next;
		}
		
		my $colors = ($$props{'COLOR'}) ? $$props{'COLOR'} : \@dfltcolors;
#
#	need column names in defined order
#
		my @colnames = ();
		foreach (keys(%$columns)) {
			$colnames[$$columns{$_}] = $_;
		}
		shift @colnames;

		if ($$dtypes[$i] eq 'BARCHART') {
#
#	first data array is domain names, the rest are
#	datasets. If more than 1 dataset is supplied, then
#	bars are grouped
#
			if ($$props{'3-D'}) {
				$img = new GD::Graph::bars3d($$props{'WIDTH'}, $$props{'HEIGHT'});
			}
			else {
				$img = new GD::Graph::bars($$props{'WIDTH'}, $$props{'HEIGHT'});
			}

			$img->set( x_label => $$props{'X-AXIS'})
				if ($$props{'X-AXIS'});
			$img->set( y_label => $$props{'Y-AXIS'})
				if ($$props{'Y-AXIS'});
			$img->set( title => $$props{'TITLE'})
				if ($$props{'TITLE'});
			$img->set ('y_long_ticks' => 1)
				if ($$props{'SHOWGRID'});
			$img->set ('show_values' => 1)
				if ($$props{'SHOWVALUES'});

			$img->set( 
   				y_tick_number	=> 10,
   				dclrs	=> $colors,
   				legend_placement	=> 'RB',
   				x_label_position	=> 1/2,
   				y_long_ticks => 1,
   				transparent	=> 0,
			    zero_axis	=> 1,
			    values_vertical => 1,
			    overwrite	=> 0,
				cycle_clrs => ((scalar(@$data) > 2) ? 0 : 1)
			);
			$img->set_legend(@colnames)
				if (scalar(@$data) > 2);
#
#	to add some spacing between groups of bars, we need to plot
#	some undef's
#
			if (scalar(@$data) > 2) {
				my @tdata = @$data;
				my $s = $tdata[0];
				my @t = (undef) x scalar(@$s);
				push(@tdata, \@t);
			
				$img->plot(\@tdata);
			}
			else {
				$img->plot($data);
			}
			$sth->{'chart_image'} = $img->gd->png();
			next;
		}
#
# must be candle, line, point, or area
#	
		my @colors = ();
		my $clist = ($$props{'COLOR'}) ? $$props{'COLOR'} : \@dfltcolors;
		for ($k = 1, $j = 0; $k < scalar(@$data); $k++) {
			push(@colors, $$clist[$j++]);
			$j = 0 if ($j >= scalar(@$clist));
		}
		my @shapes = ();
		my $shapelist = ($$props{'SHAPE'}) ? $$props{'SHAPE'} : [ 'fillcircle' ];
		for ($k = 1, $j = 0; $k < scalar(@$data); $k++) {
			push(@shapes, $$shapelist[$j++]);
			$j = 0 if ($j >= scalar(@$shapelist));
		}

		$img = DBD::Chart::Plot->new($$props{'WIDTH'}, $$props{'HEIGHT'});
		$img->setOptions( 'xAxisLabel' => $$props{'X-AXIS'})
			if ($$props{'X-AXIS'});
		$img->setOptions( 'yAxisLabel' => $$props{'Y-AXIS'})
			if ($$props{'Y-AXIS'});
		$img->setOptions( 'zAxisLabel' => $$props{'Z-AXIS'})
			if ($$props{'Z-AXIS'});
			
		$img->setOptions( 'title' => $$props{'TITLE'})
			if ($$props{'TITLE'});
		$img->setOptions( 'horizGrid' => 1, 'vertGrid' => 1)
			if ($$props{'SHOWGRID'});

		$img->setOptions( 'showValues' => 1)
			if ($$props{'SHOWVALUES'});

		$img->setOptions( 'xLog' => 1)
			if ($$props{'X-LOG'});
			
		$img->setOptions( 'yLog' => 1)
			if ($$props{'Y-LOG'});
			
		$img->setOptions( 'symDomain' => 1)
			if (! $numtype{$$types[0]});
			
		$img->setOptions( 'legend' => \@colnames)
			if ((($$dtypes[$i] ne 'CANDLESTICK') && (scalar(@$data) > 2)) || 
				(scalar(@$data) > 3));

		my $propstr = '';

		if ($$dtypes[$i] eq 'CANDLESTICK') {
#
#	first data array is domain symbols, the rest are
#	datasets, consisting of 2-tuples (y-min, y-max).
#	If more than 1 dataset is supplied, then stacks are grouped
#
			for (my $n = 0, $k = 1; $k < scalar(@$data); $k += 2, $n++) {
				$propstr = 'candle ' . $$colors[$n];
				$propstr .= ' ' . $shapes[$n] 
					if ($$props{'SHOWPOINTS'});
				$img->setPoints($$data[0], $$data[$k], $$data[$k+1], $propstr);
			}
			$sth->{'chart_image'} = $img->plot();
			next;
		}

		for ($k = 1; $k < scalar(@$data); $k++) {
			if ($$dtypes[$i] eq 'POINTGRAPH') {
				$propstr = 'noline ' . $$colors[$k-1] . ' ' . $shapes[$k-1];
			}
			elsif ($$dtypes[$i] eq 'LINEGRAPH') {
				$propstr = $$colors[$k-1];
				$propstr .= ' ' . $shapes[$k-1] 
					if ($$props{'SHOWPOINTS'});
			}
			elsif ($$dtypes[$i] eq 'AREAGRAPH') {
				$propstr = 'fill ' . $$colors[$k-1];
				$propstr .= ' ' . $shapes[$k-1] 
					if ($$props{'SHOWPOINTS'});
			}
			$img->setPoints($$data[0], $$data[$k], $propstr);
		}
		$sth->{'chart_image'} = $img->plot();
	}
    return 1;
}

sub eval_predicate {
	my ($predcol, $predop, $predval, $types, $data, $parms, $is_ary, $is_ref, $maxary) = @_;
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
	if (! $sth->{'NUM_OF_PARAMS'}) {
		$DBD::Chart::err = -1;
		$DBD::Chart::errstr = 'Statement does not contain placeholders.';
		return undef;
	}

	my $params = $sth->{'chart_params'};
	if (!defined($params)) {
		my @parms = ();
		$params = \@parms;
		$sth->{'chart_params'} = \@parms;
	}
	
	$$params[$pNum-1] = $val;
	1;
}
*chart_bind_param_array = \&bind_param;
*bind_param_array = \&bind_param;

sub chart_bind_param_status {
	my ($sth, $stsary) = @_;
	if ((ref $stsary ne 'ARRAY') && (ref $stsary ne 'HASH')) {
		$DBD::Chart::err = -1;
		$DBD::Chart::errstr = 
			'bind_param_status () requires arrayref or hashref parameter.';
		return undef;
	}
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
}

1;
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

THIS IS ALPHA SOFTWARE.

=head1 DESCRIPTION

The DBD::Chart provides a DBI abstraction for rendering pie charts,
bar charts, and line and point graphs.

For detailed usage information, see the included L<dbdchart.html>
webpage.
See L<DBI(3)> for details on DBI.
See L<GD(3)>, L<GD::Graph(3)> for details about the graphing engines.

=head2 Prerequisites

=over 4

=item Perl 5.005 minimum

=item DBI 1.14 minimum

=item DBD::Chart::Plot 0.10 minimum (included with this package)

=item GD::Graph 1.26 minimum

=item GD X.XX minimum

=item GD::TextUtils X.XX minimum

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

    gzip -cd DBD-Chart-0.20.tar.gz | tar xf -

and then enter the following:

    cd DBD-Chart-0.20
    perl Makefile.PL
    make
    make test

If any tests fail, let me know. Otherwise go on with

    make install

Note that you probably need root or administrator permissions.
If you don't have them, read the ExtUtils::MakeMaker man page for details
on installing in your own directories. L<ExtUtils::MakeMaker>.

=head1 FOR MORE INFO

Check out http://home.earthlink.net/~darnold/dbdchart with your 
favorite browser.  It includes all the usage information.

=head1 AUTHOR AND COPYRIGHT

This module is Copyright (C) 2001 by Dean Arnold

    Email: darnold@earthlink.net

You may distribute this module under the terms of either the GNU
General Public License or the Artistic License, as specified in
the Perl README file.

=head1 SEE ALSO

L<DBI(3)>

For help on the use of DBD::Chart, see the DBI users mailing list:

  dbi-users-subscribe@perl.org

For general information on DBI see

  http://www.symbolstone.org/technology/perl/DBI

=cut
