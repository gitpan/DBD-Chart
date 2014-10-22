#23456789012345678901234567890123456789012345678901234567890123456789012345
#
#   Copyright (c) 2001, Dean Arnold
#
#   You may distribute under the terms of the Artistic License, as 
#	specified in the Perl README file.
#
#	History:
#
#		0.61	2001-Mar-14	D. Arnold
#			Fix for multicolor histos
#			Replace hyphenated properties with
#				underscores
#			Support quoted color and shape names
#			Support IN (...) syntax for color, shape, and icon lists
#			added 'dot' shape (contributed by Andrea Spinelli)
#
#		0.60	2001-Jan-12	D. Arnold
#			Temporal datatypes
#			Appl. defined colors
#			Histograms
#			composite images (derived tables)
#			Gantt charts
#
#		0.52	2001-Dec-14	D. Arnold
#			Fixed 2-D barchart crashes
#
#		0.51	2001-Dec-01 D. Arnold
#			Support multicolor single range barcharts
#			Support for 3D piecharts
#			Support for temporal datatypes
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
'BOXCHART', 1,
'GANTT', 3
);

our %binary_props = (
'SHOWGRID', 1, 
'X_LOG', 1, 
'Y_LOG', 1, 
'THREE_D', 1, 
'SHOWPOINTS', 1, 
'SHOWVALUES', 1, 
'KEEPORIGIN', 1);
	
our %string_props = (
'X_AXIS', 1, 
'Y_AXIS', 1, 
'Z_AXIS', 1, 
'TITLE', 1, 
'SIGNATURE', 1, 
'LOGO', 1, 
'X_ORIENT', 1, 
'FORMAT', 1,
'FONT', 1,
'TEMPLATE', 1,
'MAPURL', 1,
'MAPSCRIPT', 1,
'MAPNAME', 1,
'MAPTYPE', 1
);

our %trans_props = (
'X-AXIS', 'X_AXIS',
'Y-AXIS', 'Y_AXIS',
'Z-AXIS', 'Z_AXIS',
'X-LOG', 'X_LOG',
'Y-LOG', 'Y_LOG',
'3-D', 'THREE_D',
'Y-MAX', 'Y_MAX',
'Y-MIN', 'Y_MIN',
'COLORS', 'COLOR',
'ICONS', 'ICON',
'SHAPES', 'SHAPE'
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
'X_AXIS', 1, 
'Y_AXIS', 1,
'Z_AXIS', 1, 
'TITLE', 1, 
'COLOR', 1, 
'COLORS', 1, 
'WIDTH', 1, 
'HEIGHT', 1, 
'SHAPE', 1,
'SHAPES', 1,
'X-ORIENT', 1, 
'X_ORIENT', 1, 
'FORMAT', 1, 
'LOGO', 1, 
'X-LOG', 1, 
'Y-LOG', 1, 
'3-D', 1,
'Y-MAX', 1, 
'Y-MIN', 1,
'X_LOG', 1, 
'Y_LOG', 1, 
'THREE_D', 1,
'Y_MAX', 1, 
'Y_MIN', 1,
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
'icon', 9,
'dot', 10);

{
package DBD::Chart;

use DBI;
use DBI qw(:sql_types);

# Do NOT @EXPORT anything.
$DBD::Chart::VERSION = '0.61';

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
#
#	generate the base colormap
#
	my %table = ();
	$table{columns} = { 
		'NAME' => 0,
		'REDVALUE' => 1,
		'GREENVALUE' => 2,
		'BLUEVALUE' => 3 };
	$table{types} = [ SQL_VARCHAR, SQL_INTEGER,  SQL_INTEGER,  SQL_INTEGER ];
	$table{precisions} = [ 30, 4, 4, 4 ];
	$table{scales} = [ 0, 0, 0, 0 ];
	$table{version} = 1.0;
	my @ary = ( [ ], [ ], [ ], [ ] );
	foreach my $color (keys(%valid_colors)) {
		push(@{$ary[0]}, $color);
		push(@{$ary[1]}, $valid_colors{$color}->[0]);
		push(@{$ary[2]}, $valid_colors{$color}->[1]);
		push(@{$ary[3]}, $valid_colors{$color}->[2]);
	}
	$table{data} = \@ary;
	$DBD::Chart::charts{COLORMAP} = \%table;

	return $DBD::Chart::drh;
}

1;
}

#
#	check on attributes
#
{   package DBD::Chart::dr; # ====== DRIVER ======
$DBD::Chart::dr::imp_data_size = 0;

# we use default connect()

sub disconnect_all { }
sub DESTROY { undef }

1;
}

{   package DBD::Chart::db; # ====== DATABASE ======
    $DBD::Chart::db::imp_data_size = 0;
    use Carp;

use DBI qw(:sql_types);
use constant SQL_INTERVAL_HR2SEC => 110;
#
#	for compatibility between DBI pre 1.200
#	and new DBI

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
'INTERVAL', SQL_INTERVAL_HR2SEC,
'TIME', SQL_TIME
);

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
'TIME', 16
);

my %inv_pieprop = (
'SHAPE', 1, 
'SHAPES', 1, 
'SHOWGRID', 1, 
'SHOWPOINTS', 1, 
'X-AXIS', 1, 
'Y-AXIS', 1, 
'Z-AXIS', 1, 
'X_AXIS', 1, 
'Y_AXIS', 1, 
'Z_AXIS', 1, 
'SHOWVALUES', 1, 
'X-LOG', 1, 
'Y-LOG', 1, 
'Y-MAX', 1, 
'Y-MIN', 1,
'X_LOG', 1, 
'Y_LOG', 1, 
'Y_MAX', 1, 
'Y_MIN', 1,
'ICON', 1,
'ICONS', 1
);

my %inv_barprop = (
'SHAPE', 1, 
'SHAPES', 1, 
'SHOWPOINTS', 1, 
'X-LOG', 1,
'X_LOG', 1
);

my %inv_candle = (
'X_LOG', 1,
'THREE_D', 1,
'X-LOG', 1,
'3-D', 1
);
#
#	defaults for simple queries
my %dfltprops = ( 
'SHAPE', undef, 
'WIDTH', 300, 
'HEIGHT', 300,
'SHOWGRID', 0, 
'SHOWPOINTS', 0, 
'SHOWVALUES', 0, 
'X_AXIS', 'X axis', 
'Y_AXIS', 'Y axis', 
'Z_AXIS', undef, 
'TITLE', '', 
'COLORS', \@dfltcolors, 
'X_LOG', 0, 
'Y_LOG', 0, 
'THREE_D', 0, 
'BACKGROUND', 'white',
'SIGNATURE', undef, 
'LOGO', undef, 
'X_ORIENT', 'DEFAULT', 
'FORMAT', 'PNG',
'KEEPORIGIN', 0, 
'Y_MAX', undef, 
'Y_MIN', undef,
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
#
#	default globals for composite queries
my %dfltglobals = ( 
'WIDTH', 300, 
'HEIGHT', 300,
'SHOWGRID', 0, 
'X_AXIS', 'X axis', 
'Y_AXIS', 'Y axis', 
'TITLE', '', 
'X_LOG', 0, 
'Y_LOG', 0, 
'THREE_D', 0, 
'BACKGROUND', 'white',
'SIGNATURE', undef, 
'LOGO', undef, 
'X_ORIENT', 'DEFAULT', 
'FORMAT', 'PNG',
'KEEPORIGIN', 0, 
'FONT', undef,
'GRIDCOLOR', 'black',
'TEXTCOLOR', 'black',
'TEMPLATE', undef,
'MAPURL', undef,
'MAPSCRIPT', undef,
'MAPNAME', undef,
'MAPTYPE', undef
);
#
#	default subquery props for composite queries
my %dfltcomposites = (
'SHAPE', undef, 
'SHOWPOINTS', 0, 
'SHOWVALUES', 0, 
'COLORS', \@dfltcolors, 
'ICONS', undef,
);
#
#	map of compatible chart types in composite
#	images
my %compatibility = (
'PIECHART', undef,
'BOXCHART', 
	{
	'BARCHART' => 1,
	'POINTGRAPH' => 1,
	'LINEGRAPH' => 1,
	'AREAGRAPH' => 1,
	'CANDLESTICK' => 1,
	'BOXCHART' => 1
	},
'HISTOGRAM', { 'HISTOGRAM' => 1 },
'SURFACEMAP', { 'SURFACEMAP' => 1 },
'BARCHART', 
	{ 
	'BARCHART' => 1,
	'POINTGRAPH' => 1,
	'LINEGRAPH' => 1,
	'AREAGRAPH' => 1,
	'CANDLESTICK' => 1,
	'BOXCHART' => 1
	},

'POINTGRAPH',
	{ 
	'BARCHART' => 1,
	'POINTGRAPH' => 1,
	'LINEGRAPH' => 1,
	'AREAGRAPH' => 1,
	'CANDLESTICK' => 1,
	'BOXCHART' => 1
	},
'LINEGRAPH',
	{ 
	'BARCHART' => 1,
	'POINTGRAPH' => 1,
	'LINEGRAPH' => 1,
	'AREAGRAPH' => 1,
	'BOXCHART' => 1,
	'CANDLESTICK' => 1
	},
'AREAGRAPH',
	{ 
	'BARCHART' => 1,
	'POINTGRAPH' => 1,
	'LINEGRAPH' => 1,
	'AREAGRAPH' => 1,
	'BOXCHART' => 1,
	'CANDLESTICK' => 1
	},
'CANDLESTICK', 
	{ 
	'BARCHART' => 1,
	'POINTGRAPH' => 1,
	'LINEGRAPH' => 1,
	'AREAGRAPH' => 1,
	'BOXCHART' => 1,
	'CANDLESTICK' => 1
	}
);
#
#	map the global properties for composites
my %global_props	= ( 
'BACKGROUND', 1,
'KEEPORIGIN', 1, 
'SIGNATURE', 1, 
'SHOWGRID', 1, 
'X_AXIS', 1,
'Y_AXIS', 1,
'Z_AXIS', 1,
'TITLE', 1,
'WIDTH', 1, 
'HEIGHT', 1, 
'X_ORIENT', 1, 
'FORMAT', 1,
'LOGO', 1,
'X_LOG', 1,
'Y_LOG', 1,
'THREE_D', 1,
'Y_MAX', 1,
'Y_MIN', 1,
'TEMPLATE', 1,
'GRIDCOLOR', 1,
'TEXTCOLOR', 1,
'MAPURL', 1,
'MAPSCRIPT', 1,
'MAPNAME', 1,
'MAPTYPE', 1
);

sub check_color {
	my ($color) = @_;
	
	my $table = $DBD::Chart::charts{COLORMAP};
	my $col1 = $table->{data}->[0];
	my $c;
	foreach $c (@$col1) {
		return 1 if ($color eq $c);
	}
	return undef;
}

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
			if (($decl) = /^\s*\S+\s+(TIMESTAMP|SMALLINT|INTERVAL|TINYINT|VARCHAR|FLOAT|CHAR|DATE|TIME|INT|DEC)\s*$/i);
			
		push(@$typelen, $decsz),
		push(@$typescale, 0),
		push(@$typeary, $typeval{$decl}),
		next
			if (($decl, $decsz) = /^\s*\S+\s+(VARCHAR|CHAR)\s*\((\d+)\)\s*$/i);

		push(@$typelen, $decsz),
		push(@$typescale, 0),
		push(@$typeary, SQL_DECIMAL),
		next
			if ((($decsz) = /^\s*\S+\s+DEC\s*\((\d+)\)\s*$/i) &&
				($decsz < 19) && ($decsz > 0));
#
#	handle scaled decimal declarations
#
		push(@$typelen, $decsz),
		push(@$typescale, $decscal),
		push(@$typeary, SQL_DECIMAL),
		next
			if ((($decsz, $decscal) = 
				/^\s*\S+\s+DEC\s*\((\d+);(\d+)\)\s*$/i) && 
				($decsz < 19) && ($decsz > 0) && ($decscal < $decsz));

# if we get here, we've got something bogus
		$DBD::Chart::err = -1;
		$_=~s/;/,/;
		$DBD::Chart::errstr = "Invalid column definition $_"; ;
		return undef;
	}
	return $i;
}

sub restore_strings {
	my ($prop, $t, $strlits) = @_;

	$DBD::Chart::err = -1,
	$DBD::Chart::errstr = "$prop property requires a string.",
	return undef
		unless ($t=~/^<\d+>/);
#
#	in case it was an empty string, restore the quotes
	my $str = '\'';
	$str .= $$strlits[$1]. '\'',
	$t = $2
		while ($t=~/^<(\d+)>(.*)$/);

	$DBD::Chart::err = -1,
	$DBD::Chart::errstr = "$prop property requires a string.",
	return undef
		if ($t ne '');

	$str=~s/''/'/g;
	$str=~s/^'(.*)'$/$1/g;
	return $str;
}

sub parse_props {
	my ($ctype, $t, $numphs, $is_subquery, $strlits) = @_;
	
	my %props = $is_subquery ? %dfltcomposites : ($ctype eq 'IMAGE' ? %dfltglobals : %dfltprops);
	my ($prop, $op);
	$t=~s/\s*AND\s*/\r/ig;
	my @preds = split("\r", $t);

	foreach (@preds) {

		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = "Unrecognized property declaration.",
		return (undef, $t)
			unless (($prop, $op, $t)=/^([^\s=]+)\s*(=|IN)\s*(.+)$/i);

		$prop = uc $prop;
		$op = uc $op;
		$t=~s/\s*$//;

		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = "Unrecognized property $prop.",
		return (undef, $t)
			unless $valid_props{$prop};
#
#	translate the property if it has synonym
		$prop = $trans_props{$prop} if $trans_props{$prop};

		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = "Property $prop not valid with valuelist.",
		return (undef, $t)
			if (($op eq 'IN') && ($prop!~/^COLOR|SHAPE|ICON$/));

		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = "Property $prop not valid in subquery.",
		return (undef, $t)
			if ($is_subquery && $global_props{$prop});
#
#	got a placeholder
#
		$props{ $prop } = "?$$numphs",
		$$numphs++,
		next
			if ($t eq '?');
		
		if ($binary_props{$prop}) {
#
#	make sure its zero or 1
#
			$props{ $prop } = $t,
			next
				if (($t == 1) || ($t == 0));

			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = "Invalid value for $prop property.";
			return (undef, $t);
		}
		if ($string_props{$prop}) {

			$props{$prop} = restore_strings($prop, $t, $strlits);
			return (undef, $t)
				unless defined($props{$prop});
			next;
		}
		if (($prop eq 'WIDTH') || ($prop eq 'HEIGHT')) {

			$props{ $prop } = $t,
			next
				if (($t=~/^\d+$/) && ($t >= 10) && ($t <= 100000));

			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = "Invalid value for $prop property.";
			return (undef, $t);
		}

		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 
			"Y_MAX and Y_MIN deprecated as of release 0.50.",
		next
			if (($prop eq 'Y_MAX') || ($prop eq 'Y_MIN'));

		if (($prop eq 'BACKGROUND') || ($prop eq 'GRIDCOLOR') || 
			($prop eq 'TEXTCOLOR')) { 

			$t = restore_strings($prop, $t, $strlits)
				if ($t=~/<\d+>/);
			$t = lc $t;
			$props{$prop} = $t,
			next
				if (check_color($t) || 
					(($prop eq 'BACKGROUND') && ($t eq 'transparent')));

			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = "Invalid value for $prop property.";
			return (undef, $t);
		}

 		if (($prop eq 'COLOR') || ($prop eq 'SHAPE')) {
 			my @colors = ();
			$props{ $prop } = \@colors;

			$t = restore_strings($prop, $t, $strlits)
				if ($t=~/^<\d+>$/);
			push(@colors, $t),
			next
	 			unless ($t=~/^\(([^\)]+)\)$/);

			$t = lc $1;
			$t=~s/\s+//g;
			@colors = split(',', $t);
			for (my $i = 0; $i <= $#colors; $i++) {
				$colors[$i] = "?$$numphs",
				$$numphs++,
				next
					if ($colors[$i] eq '?');

				next unless ($colors[$i]=~/^<\d+>$/);
				$colors[$i] = restore_strings($prop, $colors[$i], $strlits);
			}
			next;
 		}
 		if ($prop eq 'ICON') {
 			my @icons = ();
			$props{ $prop } = \@icons;

			$t = restore_strings($prop, $t, $strlits)
 				if ($t=~/^<\d+>$/);

			$icons[0] = $t,
			next
 				unless ($t=~/^\(([^\)]+)\)$/);

			$t = $1;
			$t=~s/\s+//g;
			@icons = split(',', $t);
			for (my $i = 0; $i <= $#icons; $i++) {
				next if (uc $icons[$i] eq 'NULL');
				$icons[$i] = "?$$numphs",
				$$numphs++,
				next
					if ($icons[$i] eq '?');
				next unless ($icons[$i]=~/^<\d+>$/);
				$icons[$i] = restore_strings($prop, $icons[$i], $strlits);
 			}
 		}
	} # end while

	if (defined($props{'COLOR'})) {
		my $colors = $props{'COLOR'};
		foreach $prop (@$colors) {
			next if check_color($prop);
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = "Unknown color $prop.",
			return (undef, $t)
		}
	}
	if (defined($props{'SHAPE'})) {
		my $shapes = $props{'SHAPE'};
		foreach $prop (@$shapes) {
			next if $valid_shapes{$prop};
			$DBD::Chart::err = -1;
			$DBD::Chart::errstr = "Unknown point shape $prop.";
			return (undef, $t);
		}
	}
	$DBD::Chart::err = -1,
	$DBD::Chart::errstr = "Invalid value for 'X_ORIENT' property.",
	return (undef, $t)
		if (($props{'X_ORIENT'}) && 
			($props{'X_ORIENT'}!~/^(HORIZONTAL|VERTICAL|DEFAULT)$/i));

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
#
#	start pessimistically
	$DBD::Chart::err = -1;
	$DBD::Chart::errstr = "Invalid value for column $tname.";
	
	return undef
		if ((($$ctypes[$$predcol] == SQL_FLOAT) ||
			($$ctypes[$$predcol] == SQL_DECIMAL)) &&
			($collist!~/^[\+\-]?\d+(\.\d+(E[+|-]?\d+)?)$/i));

	return undef
		if ((($$ctypes[$$predcol] == SQL_INTEGER) ||
			($$ctypes[$$predcol] == SQL_SMALLINT) ||
			($$ctypes[$$predcol] == SQL_TINYINT))&&
			($collist!~/^[\+\-]?\d+$/));

	return undef
		if (($$ctypes[$$predcol] == SQL_DATE) &&
			($collist!~/^'\d+[\-\/\.](\d+|JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[\-\/\.]\d+'$/i));

	return undef
		if (($$ctypes[$$predcol] == SQL_TIMESTAMP) &&
			($collist!~/^'\d+[\-\/\.](\d+|JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[\-\/\.]\d+\s+\d+:\d+:\d+(.\d+)?'$/i));

	return undef
		if (($$ctypes[$$predcol] == SQL_TIME) &&
			($collist!~/^'\d+:\d+:\d+(.\d+)?'$/));

	return undef
		if (($$ctypes[$$predcol] == SQL_INTERVAL_HR2SEC) &&
			($collist=~/^'[\+\-]?\d+:\d+:\d+(.\d+)?'$/));

	$DBD::Chart::err = 0,
	$DBD::Chart::errstr = '',
	$$predval = $collist,
	return 1
		if (($$ctypes[$$predcol] != SQL_CHAR) && 
			($$ctypes[$$predcol] != SQL_VARCHAR));
		
	return undef
		unless ($collist=~/^('[^']*')(.*)$/);

	$$predval = $1;
	$collist = $2;

	$$predval .= $1,
	$collist= $2
		while ($collist=~/^('[^']*')(.*)$/);

	$DBD::Chart::err = 0;
	$DBD::Chart::errstr = '';
	return 1;
}

sub validate_time {
	my ($time) = @_;
	my ($hr, $min, $sec) = split(':', $time);
	return (($hr >= 0) && ($hr < 24) && ($min >= 0) && ($min < 60) && ($sec >= 0) && ($sec < 60));
}

sub validate_interval {
#
#	eventually support full intervals (years, months, days...)
#
	my ($hr, $min, $sec, $subsec) = @_;
	return undef if (defined($hr) && ($min > 60));
	return undef if (defined($min) && ($sec > 60));
#
#	convert to seconds only float value
#
	$sec += $hr * 3600 if $hr;
	$sec += $min * 60 if $min;
	$sec .= $subsec if $subsec;
	return $sec;
}

sub validate_value {
	my ($coltype, $remnant, $cprec, $errstr) = @_;

	$$remnant = $4,
	return $1
		if ((($coltype == SQL_FLOAT) ||
			($coltype == SQL_DECIMAL)) &&
			($$remnant=~/^([\+\-]?\d+(\.\d+(E[+|-]?\d+)?)?)\s*,\s*(.*)$/i));

	$$remnant = $2,
	return $1
		if ((($coltype == SQL_INTEGER) ||
			($coltype == SQL_SMALLINT) ||
			($coltype == SQL_TINYINT)) &&
			($$remnant=~/^([\+\-]?\d+)\s*,\s*(.*)$/i));

	if ($coltype == SQL_DATE) {
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = $errstr,
		return undef
			unless ($$remnant=~/^'((\d+)([\-\.\/])(\w+)([\-\.\/])(\d+))'\s*,\s*(.*)$/i);

		my ($date, $yr, $sep1, $mo, $sep2, $day) = ($1, $2, $3, uc $4, $5, $6);
		$$remnant = $7;
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = $errstr,
		return undef
			unless (((($mo=~/^\d+$/) && ($mo > 0) && ($mo < 12)) ||
				($mo=~/^(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)$/i)) &&
				($day < 32) && ($day > 0));
#
#	should probably verify date is valid!
#
		return $date;
	}
	if ($coltype == SQL_INTERVAL_HR2SEC) {
#
#	currently only support intervals up to hourly precision
#
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = $errstr,
		return undef
			unless ($$remnant=~/^'([\-\+]?(\d+:)?(\d+:)?(\d+)(\.\d+)?)'\s*,\s*(.*)$/);
		my ($time, $hr, $min, $sec, $subsec) = ($2, $3, $4, $5);
		$$remnant = $6;
		
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = $errstr,
		return undef
			unless defined(validate_interval($hr, $min, $sec, $subsec));
		return $time;
	}
	if ($coltype == SQL_TIME) {
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = $errstr,
		return undef
			unless ($$remnant=~/^'(\d\d?:\d\d:\d\d(\.\d+)?)'\s*,\s*(.*)$/i);
		my ($time, $subsec) = ($1, $2);
		$$remnant = $3;
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = $errstr,
		return undef
			unless validate_time($time);
#
#	NOTE: we discard subseconds here
#	should we permit AM/PM indications ?
#
		return $time;
	}
	if ($coltype == SQL_TIMESTAMP) {
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = $errstr,
		return undef
			unless ($$remnant=~/^'((\d+)([\-\.\/])(\w+)([\-\.\/])(\d+)\s+(\d\d?:\d\d:\d\d(\.\d+)?))'\s*,\s*(.*)$/i);
		my ($tmstamp, $yr, $sep1, $mo, $sep2, $day, $time, $subsec) = ($1, $2, $3, uc $4, $5, $6, $7, $8);
		$$remnant = $9;
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = $errstr,
		return undef
			unless (((($mo=~/^\d+$/) && ($mo > 0) && ($mo < 12)) ||
				($mo=~/^(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)$/i)) &&
				($day < 32) && ($day > 0) && validate_time($time));
#
#	should probably verify date is valid!
#	and convert to seconds since epoc (or some other baseline value)
#	NOTE: we discard subseconds here
#
		return $tmstamp;
	}
	if (($coltype == SQL_CHAR) || ($coltype == SQL_VARCHAR)) {
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = $errstr,
		return undef
			unless ($$remnant=~/^'([^']*)'(.*)$/);

		my $str = $1;
		$$remnant= $2;

		$str .= '\'' . $1,
		$$remnant= $2
			while ($$remnant=~/^'([^']*)'(.*)$/);

		$$remnant=~s/^\s*,\s*//;
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 
			"String value exceeds defined length.",
		return undef
			if (length($str) > $cprec);

		return $str;
	}
	$DBD::Chart::err = -1;
	$DBD::Chart::errstr = $errstr;
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

		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 
			'Cannot CREATE/DROP COLORMAP table.',
		return undef
			if ($filenm eq 'COLORMAP');
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
	$cscales = $$chart{'scales'}, # an arrayref of scales
		if (($cmd eq 'UPDATE') || ($cmd eq 'INSERT') || ($cmd eq 'DELETE'));

	my %cols = ();
	my @typeary = ();
	my @typelens = ();
	my @typescale = ();

	my $numphs = 0;
	my @dtypes = ();
	my @dcharts = ();
	my @dnames = ();
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

			$setcols{$cnum} = validate_value($$ctypes[$cnum], \$remnant, 
				$$cprecs[$cnum], "Invalid value for column at position $cnum.");
			return undef
				unless defined($setcols{$cnum});
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
#	scan SET list to count ph's and validate literals
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

			$collist = $1,
			push(@parmcols, $cnum),
			$numphs++,
			next
				if ($collist=~/^\?\s*,\s*(.*)$/);

			$collist = $1,
			$setcols{$cnum} = undef,
			next
				if ($collist=~/^NULL\s*,\s*(.*)$/i);

			$setcols{$cnum} = validate_value($$ctypes[$cnum], \$collist,
				$$cprecs[$cnum], "Invalid value for column $tname.");
			return undef
				unless defined($setcols{$cnum});
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
		if ($remnant=~/^\*\s+FROM\s+COLORMAP\s+(WHERE\s+NAME\s*=\s*(.+))?$/i) {
#
#	its a COLORMAP query, handle special
#
			my $charttype = 'COLORMAP';
			my $flds = uc $1;
			my $pred = uc $3;
			my($outer, $sth) = DBI::_new_sth($dbh, {
				'Statement'     => $statement,
			});
			$dversions{COLORMAP} = 1;
			$sth->{'chart_dbh'} = $dbh;
			$sth->{'chart_cmd'} = $cmd;
			$sth->{'chart_name'} = 'COLORMAP';
			$sth->{'chart_qnames'} = undef;
			$sth->{'chart_charttypes'} = [ 'COLORMAP' ];
			$sth->{'chart_sources'} = [ 'COLORMAP' ];
			$sth->{'chart_properties'} = [ $pred ];
			$sth->{'chart_version'} = \%dversions;
			$sth->{'chart_imagemap'} = undef;
			$sth->STORE('NUM_OF_FIELDS', 4);
			$sth->STORE('NUM_OF_PARAMS', 1)
				if ($pred=~/^\s*\?\s*$/);
			$sth->{'NAME'} = [ 'Name', 'RedValue', 'BlueValue', 'GreenValue' ];
			$sth->{'TYPE'} = [ SQL_VARCHAR, SQL_INTEGER, SQL_INTEGER, SQL_INTEGER ];
			$sth->{'PRECISION'} = [ 30, 4, 4, 4 ];
			$sth->{'SCALE'} = [ 0, 0, 0, 0 ];
			$sth->{'NULLABLE'} = [ undef, undef, undef, undef ];
			return $outer;
		}
#
#	normalize the query to isolate subqueries
#	replace all literal strings before processing
#
		my @strlits = ();
		my $num = 0;
		push(@strlits, $1),
		$remnant=~s/'.*?'/<$num>/,
		$num++
			while ($remnant=~/'(.*?)'/);

		$remnant=~s/\)(\s+(\w+))?\s*WHERE\s+/$1\rWHERE /i;	# isolate last predicate
		$remnant=~s/\s+FROM\s+\(\s*SELECT\s*/\r/i;	# isolate first subquery
		$remnant=~s/\s*\)(\s+(\w+))?\s*,\s*\(\s*SELECT\s*/$1\r/ig;	# isolate individual queries
		my @queries = split("\r", $remnant);

		if ($#queries > 0) {
#
#	accumulate subquery names
			foreach $i (1..$#queries) {
				next
					unless ($queries[$i]=~/\s+(\w+)$/);
				$dnames[$i] = uc $1;
				$queries[$i]=~s/\s+(\w+)$//;
			}
		}
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 'Invalid composite chart specification.',
		return undef
			unless (($#queries == 0) || 
				(($queries[0]=~/^IMAGE(\s*,\s*IMAGEMAP)?$/i) && ($queries[1]!~/^WHERE/i)));

		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 'No subqueries provided for composite chart.',
		return undef
			if (($#queries == 0) &&
				($queries[0]=~/^IMAGE(\s*,\s*IMAGEMAP)?$/i));

		my $is_composite = 1 if $#queries;
		if ($is_composite) {
#
#	get global properties
#
			$imagemap = 1 if ($queries[0]=~/^IMAGE\s*,\s*IMAGEMAP$/i);
			push(@dtypes, 'IMAGE');
			push(@dcharts, undef);
			shift @queries;
			$remnant = ($queries[$#queries]=~/^WHERE/i) ? pop(@queries) : undef;
			$dprops[0] = \%dfltglobals;
			if (($remnant) && ($remnant=~/^WHERE\s+(.+)$/i)) {
#
#	process format properties
#
				($props, $remnant) = parse_props('IMAGE', $1, \$numphs, undef, \@strlits);
				return undef if (! $props);
				$dprops[0] = $props;
			}
		}
		foreach $remnant (@queries) {
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = 'Unrecognized SELECT statement.',
			return undef
				unless ($remnant=~/^(CANDLESTICK|SURFACEMAP|POINTGRAPH|HISTOGRAM|LINEGRAPH|AREAGRAPH|PIECHART|BARCHART|BOXCHART|GANTT)(\s*,\s*IMAGEMAP)?\s+FROM\s+(\?|\w+)\s*(.*)$/i);

			$ctype = uc $1;
			$imagemap = uc $2 unless $imagemap;
			$filenm = uc $3;
			$remnant = $4;

			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = 'IMAGEMAP not valid in subquery.',
			return undef
				if (($is_composite) && ($2 ne ''));

			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = 'Incompatible chart types in composite image.',
			return undef
				if (($is_composite) && ($#dtypes > 0) && 
					(! $compatibility{$dtypes[1]}->{$ctype}));
				
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
				($props, $remnant) = parse_props($ctype, $1, \$numphs, $is_composite, \@strlits);
				return undef if (! $props);
				push(@dprops, $props);
			}
			else {
				push(@dprops, ($is_composite ? \%dfltcomposites : \%dfltprops));
			}
		}	# end foreach query
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
		$sth->{'chart_qnames'} = \@dnames;
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
use Time::Local;

$DBD::Chart::st::imp_data_size = 0;

use GD;
use DBD::Chart::Plot;

use constant SQL_INTERVAL_HR2SEC => 110;

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

my %symboltype = (
SQL_CHAR, 1,
SQL_VARCHAR, 1
);

my %timetype = (
SQL_DATE, 'YYYY-MM-DD',
SQL_TIME, 'HH:MM:SS',
SQL_TIMESTAMP, 'YYYY-MM-DD HH:MM:SS',
SQL_INTERVAL_HR2SEC, '+HH:MM:SS'
);

my %month = ( 'JAN', 0, 'FEB', 1, 'MAR', 2, 'APR', 3, 'MAY', 4, 'JUN', 5, 
'JUL', 6, 'AUG', 7, 'SEP', 8, 'OCT', 9, 'NOV', 10, 'DEC', 11);

sub check_color {
	my ($color) = @_;
	
	my $table = $DBD::Chart::charts{COLORMAP};
	my $col1 = $table->{data}->[0];
	my $c;
	foreach $c (@$col1) {
		return 1 if ($color eq $c);
	}
	return undef;
}

sub get_colormap {
	my $table = $DBD::Chart::charts{COLORMAP};
	my ($color, $r, $g, $b) = @{$table->{data}};
	my %map;
	for (my $i = 0; $i <= $#$color; $i++) {
		$map{$$color[$i]} = [ $$r[$i], $$g[$i], $$b[$i] ];
	}
	return \%map;
}

sub validate_value {
	my ($p, $ttype, $parmsts, $k, $i) = @_;

	return 1
		if (($ttype == SQL_CHAR) || ($ttype == SQL_VARCHAR));

	return 1
		if (($p=~/^[\-\+]?\d+$/) &&
			(($ttype == SQL_INTEGER) || 
			 (($ttype == SQL_SMALLINT) && ($p > -32768) && ($p < 32768)) ||
			 (($ttype == SQL_TINYINT) && ($p > -128) && ($p < 128)))
			);
		
	return 1
		if ((($ttype == SQL_FLOAT) || ($ttype == SQL_DECIMAL)) && 
			($p=~/^[\-\+]?\d+(\.\d+(E[\-\+]?\d+)?)?$/i));

	if (($ttype == SQL_DATE) &&
		($p=~/^(\d+)[\-\.\/](\w+)[\-\.\/](\d+)$/i)) {

		my ($yr, $mo, $day) = ($1, uc $2, $3);
		return 1
			if (((($mo=~/^\d+$/) && ($mo > 0) && ($mo < 12)) ||
				($mo=~/^(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)$/i)) &&
				($day < 32) && ($day > 0));
	}
	if (($ttype == SQL_INTERVAL_HR2SEC) &&
		($p=~/^[\-\+]?(\d+:)?(\d+:)?(\d+)(\.\d+)?/)) {
		my ($hr, $min, $sec, $subsec) = ($1, $2, $3, $4);
		return 1
			if (((! $min) || ($min < 60)) && ($sec < 60));
	}
	if (($ttype == SQL_TIME) &&
		($p=~/^(\d+):(\d+):(\d+)(\.\d+)?$/)) {
		my ($hr, $min, $sec, $subsec) = ($1, $2, $3, $4);
		return 1
			if (($hr < 24) && ($min < 60) && ($sec < 60));
	}
	if (($ttype == SQL_TIMESTAMP) &&
		($p=~/^(\d+)[\-\.\/](\w+)[\-\.\/](\d+)\s+(\d+):(\d+):(\d+)(\.\d+)?$/i)) {
		my ($yr, $mo, $day, $hr, $min, $sec, $subsec) = ($1, $2, uc $3, $4, $5, $6, $7);
		return 1
			if (((($mo=~/^\d+$/) && ($mo > 0) && ($mo < 12)) ||
				($mo=~/^(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)$/i)) &&
				($day < 32) && ($day > 0) &&
				($hr < 24) && ($min < 60) && ($sec < 60));
	}

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

		next if ((($prop eq 'BACKGROUND') || ($prop eq 'GRIDCOLOR') ||
			($prop eq 'TEXTCOLOR')) && (check_color($t)));

		next if (($prop eq 'X-ORIENT') && 
			($t=~/^(HORIZONTAL|VERTICAL|DEFAULT)$/i));

 		next if (($prop eq 'COLOR') && (check_color($t)));
 		
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
#
					return undef unless validate_value($p, $ttype, $parmsts, $k, $i);
				}
#
#	predicates always come last, so they'll be last param
#
				if (($predicate) && ($$predicate[2] eq '?')) {
					$ttype = $$types[$$predicate[0]];
					$p = $$parms[$i];
					$p = (($is_parmary) ? $$p[$k] : $$p) if ($is_parmref);
#
#	verify param types and literals are compatible with target fields
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

					return undef unless validate_value($p, $ttype, $parmsts, $k, $i);
				}
			}
		}
	}
#
#	for COLORMAP, we need to validate before applying
#
	if ($name eq 'COLORMAP') {
#
#	check literals
#
		foreach $i (keys(%$setcols)) {
			my $v = $$setcols{$i};
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = 
				'NULL values not valid for COLORMAP fields.',
			return undef
				unless defined($v);

			next unless $i;	# only proceed for RGB values
				
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = 
				'Invalid value for COLORMAP component field.',
			return undef
				if (($v < 0) || ($v > 255)); 
		}
#
#	then check params
#
		for ($j = 0; $j < scalar(@$paramcols); $j++) {
			$i = $$paramcols[$j];

			for ($k = 0; $k < $maxary; $k++) {

				$p = $$parms[$j];
				$p = (($is_parmary) ? $$p[$k] : $$p) if ($is_parmref);

				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = 
					'NULL values not valid for COLORMAP fields.',
				return undef
					unless defined($p);
#
#	need to push this error on the param status list (if one exists)
#
				next unless $i; # only proceed for RGB components

				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = 
			"Invalid value for COLORMAP component field.",
				return undef
					if (($p!~/^\d+$/) || ($p > 255));
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
		$k = 1;
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

				if (defined($p) &&
					(($ttype == SQL_CHAR) || ($ttype == SQL_VARCHAR)) &&
					(length($p) > $$precs[$i])) {
#
#	need to push this error on the param status list (if one exists)
#
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = 
				"Supplied value truncated at parameter $j.";

					$p = substr($p, 0, $$precs[$i]);

					$$parmsts[$k] = 
				"Supplied value truncated at parameter $j."
						if ($parmsts && (ref $parmsts eq 'ARRAY'));
					$$parmsts{$k} = 
				"Supplied value truncated at parameter $j."
						if ($parmsts && (ref $parmsts ne 'ARRAY'));
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

				if (defined($p) &&
					(($ttype == SQL_CHAR) || ($ttype == SQL_VARCHAR)) &&
					(length($p) > $$precs[$i])) {
#
#	need to push this error on the param status list (if one exists)
#
					$DBD::Chart::err = -1;
					$DBD::Chart::errstr = 
				"Supplied value truncated at parameter $j.";

					$p = substr($p, 0, $$precs[$i]);

					$$parmsts[$k] = 
				"Supplied value truncated at parameter $j."
						if ($parmsts && (ref $parmsts eq 'ARRAY'));
					$$parmsts{$k} = 
				"Supplied value truncated at parameter $j."
						if ($parmsts && (ref $parmsts ne 'ARRAY'));
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
	my $dnames = $sth->{'chart_qnames'};
	my $srcsth;
#
#	if COLORMAP, just fetch and return
#
	if ($$dcharts[0] eq 'COLORMAP') {
		my $table = $DBD::Chart::charts{COLORMAP};
		my $col1 = $table->{data}->[0];
		if (defined($$props{NAME})) {
#
#	selecting single color, setup for the fetch
#
			if ($$props{NAME}=~/^\?(\d+)$/) {
				my $phnum = $1;

				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = 'Insufficient parameters provided.',
				return undef
					if ($phnum > scalar(@$parms));

				$sth->{chart_colormap} = $$parms[$phnum];
			}
			else {
				$sth->{chart_colormap} = $$props{NAME};
			}
			my $color;
			foreach $color (@$col1) {
				last if ($color eq $sth->{chart_colormap});
			}
			return '0E0' if ($color ne $sth->{chart_colormap});
			$sth->{chart_1_color} = 1;
			return 1;
		}
#
#	selecting all colors
#
		delete $sth->{chart_1_color};
		$sth->{chart_colormap} = 0;
		return scalar @$col1;
	}

	for ($i = 0; $i <= $#$dcharts; $i++) {
		$name = $$dcharts[$i];
		next unless (($i > 0) || $name); # for composite images
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
	my $xdomain;
	my $ydomain;
	my $zdomain;
	my @legends = ();
#
#	need to determine domain type prior to adding points
	my $is_symbolic = undef;
	for ($i = 0; $i < scalar(@$dtypes); $i++) {
		$is_symbolic = 1, last
			if (($$dtypes[$i] eq 'BARCHART') ||
				($$dtypes[$i] eq 'HISTOGRAM') ||
				($$dtypes[$i] eq 'CANDLESTICK'));
	}

	for ($i = 0; $i < scalar(@$dtypes); $i++) {

		if ($$dtypes[$i] ne 'IMAGE') {
			if ($$dcharts[$i]=~/^\?(\d+)$/) {
#
#	synthesize a chart structure from the stmt handle
#	NOTE: we should eventually support array binding here!!!
#
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
		}

		$props = $$dprops[$i];
#
#	validate and copy in any placeholder values
#
		return undef if (! validate_properties($props, $parms));

		if ($i == 0) {
#
#	create plot object
#
			$img = DBD::Chart::Plot->new($$props{WIDTH}, $$props{HEIGHT}, 
				get_colormap());
			return undef unless $img;
#
#	set global properties
#
			$img->setOptions( bgColor => $$props{BACKGROUND},
				textColor => $$props{TEXTCOLOR},
				gridColor => $$props{GRIDCOLOR} ,
				threed => $$props{THREE_D});

			$img->setOptions( title => $$props{TITLE})
				if $$props{TITLE};
				
			$img->setOptions( signature => $$props{SIGNATURE})
				if $$props{SIGNATURE};
				
			$img->setOptions( 
				genMap => ($$props{MAPNAME}) ? $$props{MAPNAME} : 'plot', 
				mapType => $sth->{chart_imagemap},
				mapURL => $$props{MAPURL},
				mapScript => $$props{MAPSCRIPT},
				mapType => ($$props{MAPTYPE}) ? $$props{MAPTYPE} : 'HTML'
			)
				if $sth->{chart_imagemap};

			$img->setOptions( logo => $$props{LOGO}) if $$props{LOGO};

			$img->setOptions( 'xAxisLabel' => $$props{'X_AXIS'})
				if ($$props{'X_AXIS'});
			$img->setOptions( 'yAxisLabel' => $$props{'Y_AXIS'})
				if ($$props{'Y_AXIS'});
			$img->setOptions( 'zAxisLabel' => $$props{'Z_AXIS'})
				if ($$props{'Z_AXIS'});
			
			$img->setOptions( 'xAxisVert' => ($$props{'X_ORIENT'} eq 'VERTICAL'))
				if ($$props{'X_ORIENT'});
			
			$img->setOptions( 'horizGrid' => 1, 
				'vertGrid' => ($$dtypes[$i] ne 'BARCHART'))
				if ($$props{'SHOWGRID'});

			$img->setOptions( 'xLog' => 1)
				if ($$props{'X_LOG'});
			
			$img->setOptions( 'yLog' => 1)
				if ($$props{'Y_LOG'});
			
			$img->setOptions( 'keepOrigin' => 1)
				if ($$props{'KEEPORIGIN'});
		}

		next if ($$dtypes[$i] eq 'IMAGE');	# specific chart processing from here on
#
#	establish color list
#
		my @colors = ();
		my $clist = ($$props{'COLOR'}) ? $$props{'COLOR'} : \@dfltcolors;
		$t = ($$dtypes[$i] eq 'PIECHART') ? scalar @{$$data[0]} : scalar @$data;
		$t-- unless (($$dtypes[$i] eq 'BOXCHART') || # ($$dtypes[$i] eq 'HISTOGRAM') || 
			($$dtypes[$i] eq 'PIECHART'));
		$t /= 2 if ($$dtypes[$i] eq 'CANDLESTICK');
		$t = 1 if ($$props{'Z_AXIS'});
		$t = scalar @{$$data[0]}
			if ((($$dtypes[$i] eq 'BARCHART') || ($$dtypes[$i] eq 'HISTOGRAM')) && 
			(scalar @$clist > 1) && (scalar @$data == 2));
		for ($k = 0, $j = 0; $k < $t; $k++) {
			push(@colors, $$clist[$j++]);
			$j = 0 if ($j >= scalar(@$clist));
		}

		my $propstr = '';
#
#	select domain type: numeric, symbolic, or temporal
#	and make sure every chart adheres to compatible types
#
		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 'Incompatible domain types for composite image.',
		return undef
			unless ((! $xdomain) || 
				($numtype{$xdomain} && $numtype{$$types[0]}) ||
				($timetype{$xdomain} && $timetype{$$types[0]} &&
					($timetype{$xdomain} eq $timetype{$$types[0]})) ||
				($symboltype{$xdomain} && $symboltype{$$types[0]}));
		$xdomain = $$types[0] unless $xdomain;

		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 'Incompatible range types for composite image.',
		return undef
			unless ((! $ydomain) || ($$dtypes[$i] eq 'BOXCHART') ||
				($numtype{$ydomain} && $numtype{$$types[1]}) ||
				($timetype{$ydomain} && $timetype{$$types[1]} &&
					($timetype{$ydomain} eq $timetype{$$types[1]})));
		$ydomain = $$types[1] 
			unless ($ydomain || ($$dtypes[$i] eq 'BOXCHART'));

		$DBD::Chart::err = -1,
		$DBD::Chart::errstr = 'Incompatible Z axis types for composite image.',
		return undef
			unless ((! $zdomain) || 
				($numtype{$zdomain} && $numtype{$$types[2]}) ||
				($timetype{$zdomain} && $timetype{$$types[2]} &&
					($timetype{$zdomain} eq $timetype{$$types[2]})) ||
				($symboltype{$zdomain} && $symboltype{$$types[2]}));

		$zdomain = $$types[2] if ((! $zdomain) && $$props{'Z_AXIS'});
		$img->setOptions( 'symDomain' => 1)
			if ($is_symbolic || 
				($symboltype{$xdomain} && ($$dtypes[$i] ne 'GANTT')));
		$img->setOptions( 'timeDomain' => $timetype{$xdomain})
			if $timetype{$xdomain};
		$img->setOptions( 'timeRange' => $timetype{$ydomain})
			if $timetype{$ydomain};
#
#	we need to support temporal Z-axis!!!
#
#	Piechart:
#	first data array is domain names, the 2nd is the 
#	datasets. If more than 1 dataset is supplied, the
#	rest are ignored
#
		if ($$dtypes[$i] eq 'PIECHART') {
			$propstr = 'pie ' . join(' ', @colors);
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = $img->{errmsg},
			return undef 
				unless $img->setPoints($$data[0], $$data[1], $propstr);
			next;
		}
#
#	Gantt chart:
#	first data array is task names, 2nd is the start date,
#	3rd is end date. Add'l optionals are assignee, pct. complete,
#	and any number of dependent tasks
#
		if ($$dtypes[$i] eq 'GANTT') {
			$propstr = "gantt $colors[0]";
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = $img->{errmsg},
			return undef 
				unless $img->setPoints(@$data, $propstr);
			next;
		}
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

		$img->setOptions( 'showValues' => 1)
			if ($$props{'SHOWVALUES'});
#
#	default x-axis label orientation is vertical for candlesticks
#	and symbollic domains
#
		$img->setOptions( 'xAxisVert' => ($$props{'X_ORIENT'} ne 'HORIZONTAL'))
			if ((! $numtype{$$types[0]}) || ($$dtypes[$i] eq 'CANDLESTICK'));
#
#	force a legend if more than 1 range or plot
#	complicated algorithm here;
#		if multirange or composite {
#			if multirange {
#				push each column name onto legends array, prepended with
#					current query name if available
#			}
#		} else { must be a composite
#			push query name (default PLOTn) onto legends array
#		}
#
		if (! $$props{'Z_AXIS'}) {
			if ((($$dtypes[$i] ne 'CANDLESTICK') && (scalar(@$data) > 2)) || 
				(($$dtypes[$i] eq 'BOXCHART') && (scalar(@$data) > 1)) ||
				(scalar(@$data) > 3)) {
#	its multirange
				my $incr = ($$dtypes[$i] ne 'CANDLESTICK') ? 1 : 2;
				for (my $c = 0; $c <= $#colnames; $c += $incr) {
#
#	prepend query names if provided for composites
					push(@legends, ($$dnames[$i] . '.' . $colnames[$c])),
					next
						if ($$dnames[$i]);
					push(@legends, $colnames[$c]);
				}
			}
			elsif ($#$dtypes > 1) {
#
#	single range, composite
				push(@legends, ($$dnames[$i] ? $$dnames[$i] : "PLOT$i"));
			}
		}
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

		if (($$dtypes[$i] eq 'BARCHART') ||
			($$dtypes[$i] eq 'HISTOGRAM')) {
#
#	first data array is domain names, the rest are
#	datasets. If more than 1 dataset is supplied, then
#	bars are grouped
#
			$propstr = ($$dtypes[$i] eq 'HISTOGRAM') ? 'histo ' : 'bar ';
			if ($$props{'Z_AXIS'}) {
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = $img->{errmsg},
				return undef
					unless $img->setPoints($$data[0], $$data[1], $$data[2], 
						$propstr . $colors[0]),
				next;
			}
#
#	if single domain and multiple colors, then push all colors into
#	the property string
			if (($#$data == 1) && (! $$props{ICON})) {
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = $img->{errmsg},
				return undef
					unless $img->setPoints($$data[0], $$data[1],
						$propstr . join(' ', @colors)),
				next;
			}

			for ($i=1; $i <= $#$data; $i++) {
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = $img->{errmsg},
				return undef
					unless $img->setPoints($$data[0], $$data[$i],
						$propstr . ($$props{ICON} ? 'icon' : $colors[$i-1]));
			}
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
		if ($$props{ICON}) {
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = $img->{errmsg},
			return undef
				unless $img->setOptions( icons => \@icons )
		}

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
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = $img->{errmsg},
				return undef
					unless $img->setPoints($$data[0], $$data[$k], $$data[$k+1], $propstr);
			}
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
				$DBD::Chart::err = -1,
				$DBD::Chart::errstr = $img->{errmsg},
				return undef
					unless $img->setPoints($$data[$k], $propstr);
			}
			next;
		}
#
#	line, point, or area graph
#
		for ($k = 1; $k <= $#$data; $k++) {
			$propstr = ($$dtypes[$i] eq 'POINTGRAPH') ?
				'noline ' . $colors[$k-1] . ' ' . $shapes[$k-1] :
				($$dtypes[$i] eq 'LINEGRAPH') ? 
					$colors[$k-1] :
					'fill ' . $colors[$k-1] ;
			$propstr .= ' ' . $shapes[$k-1] 
				if ($$props{'SHOWPOINTS'} || $$props{'SHAPE'});
			$DBD::Chart::err = -1,
			$DBD::Chart::errstr = $img->{errmsg},
			return undef
				unless $img->setPoints($$data[0], $$data[$k], $propstr);
		}
	}
#
#	if we have a legend, add it before plotting
	$img->setOptions( 'legend' => \@legends)
		if ($#legends >= 0);
#
#	all the image data loaded, now plot it
#
	$sth->{'chart_image'} = $img->plot($dprops->[0]->{'FORMAT'}),
	$sth->{'chart_imagemap'} = 
		($sth->{chart_imagemap}) ? $img->getMap() : undef,
#
#	update precision values
	$precs = $sth->{PRECISION};
	$$precs[0] = length($sth->{chart_image});
	$$precs[1] = length($sth->{chart_imagemap}) if $sth->{chart_imagemap};
    return 1;
}

sub convert_time {
	my ($value, $type) = @_;
#
#	use Perl funcs to compute seconds from date
	return timegm(0, 0, 0, $3, $2 - 1, $1)
		if (($type == SQL_DATE) &&
			($value=~/^(\d+)[\-\.\/](\d+)[\-\.\/](\d+)$/));

	return timegm(0, 0, 0, $3, $month{uc $2}, $1)
		if (($type == SQL_DATE) &&
			($value=~/^(\d+)[\-\.\/](\w+)[\-\.\/](\d+)$/));

	return timegm($6, $5, $4, $3, $2 - 1, $1) + ($7 ? $7 : 0)
		if (($type == SQL_TIMESTAMP) &&
			($value=~/^(\d+)[\-\.\/](\d+)[\-\.\/](\d+)\s+(\d+):(\d+):(\d+)(\.\d+)?$/));

	return timegm($6, $5, $4, $3, $month{uc $2}, $1) + ($7 ? $7 : 0)
		if (($type == SQL_TIMESTAMP) &&
			($value=~/^(\d+)[\-\.\/](\w+)[\-\.\/](\d+)\s+(\d+):(\d+):(\d+)(\.\d+)?$/));

	return (($1 ? (($1 eq '-') ? -1 : 1) : 1) * 
		(($3 ? ($3 * 3600) : 0) + ($5 ? ($5 * 60) : 0) + $6 + ($7 ? $7 : 0)))
		if ((($type == SQL_INTERVAL_HR2SEC) || ($type == SQL_TIME)) && 
			($value=~/^([\-\+])?((\d+):)?((\d+):)?(\d+)(\.\d+)?$/));

	return undef; # for completeness, shouldn't get here
}

sub test_predicate {
	my ($rowmap, $pctype, $pc, $predop, $predval, $rownum) = @_;
	for (my $i = 0; $i <= $#$pc; $i++) {
		$$rowmap{$i} = -1, next
			if ((($pctype == SQL_CHAR) || ($pctype == SQL_VARCHAR)) &&
				(eval "\'$$pc[$i]\' $strpredops{$predop} \'$predval\'"));

		$$rowmap{$i} = -1, next
			if (($numtype{$pctype}) &&
				(eval "$$pc[$i] $numpredops{$predop} $predval"));

		if ($timetype{$pctype}) {
			my ($col, $operand) = (convert_time($$pc[$i], $pctype), convert_time($predval, $pctype));
			$$rowmap{$i} = -1
				if (eval "$col $numpredops{$predop} $operand");
		}
	}
	return 1;
}

sub eval_predicate {
	my ($predcol, $predop, $predval, $types, $data, $parms, $is_ary, 
		$is_ref, $maxary) = @_;
	my %rowmap = ();
	my $pc = $$data[$predcol];
	my $pctype = $$types[$predcol];
	my ($k, $p);
	
	$predval=~s/^'(.+)'$/$1/,	# trim any quotes
	test_predicate(\%rowmap, $pctype, $pc, $predop, $predval, -1),
	return %rowmap
		if ($predval ne '?');
#
#	must be parameterized predicate
#
	my $parmnum = $#$parms;
	for ($k = 0; $k < $maxary; $k++) {
		$p = $$parms[$parmnum];
		$p = (($is_ary) ? $$p[$k] : $$p) if ($is_ref);
		test_predicate(\%rowmap, $pctype, $pc, $predop, $p, $k);
	}
	return %rowmap;
}


sub fetch {
	my($sth) = @_;

	if ($sth->{chart_colormap}) {
		my $i = uc $sth->{chart_colormap};
		my $table = $DBD::Chart::charts{COLORMAP};
		my $ary = $table->{data};
		my ($col1, $col2, $col3, $col4) = ($$ary[0], $$ary[1], $$ary[2], $$ary[3]) ;
		if ($sth->{chart_1_color}) {
			my $color;
			foreach $color (@$col1) {
				last if ($i eq uc $color);
			}
			return '0E0' if ($i ne uc $color);
			$sth->{chart_colormap} = undef;
		}

		my @row = ($$col1[$i], $$col2[$i], $$col3[$i], $$col4[$i]);
		$sth->{chart_colormap}++;
		return $sth->_set_fbav(\@row);
	}
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
bar charts, box&whisker charts (aka boxcharts), histograms,
Gantt charts, and line, point, and area graphs.

For detailed usage information, see the included L<dbdchart.html>
webpage.
See L<DBI(3)> for details on DBI.
See L<GD(3)>, L<GD::Graph(3)> for details about the graphing engines.

=head2 Prerequisites

=over 4

=item Perl 5.6.0 minimum

=item DBI 1.14 minimum

=item DBD::Chart::Plot 0.61 (included with this package)

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

    gzip -cd DBD-Chart-0.61.tar.gz | tar xf -

and then enter the following:

    cd DBD-Chart-0.61
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

This module is Copyright (C) 2001, 2002 by Presicient Corporation

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
